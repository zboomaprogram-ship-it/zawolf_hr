const test = require('node:test');
const assert = require('node:assert/strict');
const { handleRemotePolicyRequest } = require('../remote-work/policy-router');

function fakeDb(initial = {}) {
  const docs = new Map(Object.entries(initial));
  const ref = (path) => ({
    path,
    get: async () => ({ exists: docs.has(path), data: () => docs.get(path) }),
  });
  return {
    docs,
    collection(name) {
      return {
        doc: (id) => ref(`${name}/${id}`),
        where(field, operator, value) {
          const query = { filters: [[field, operator, value]], max: 100 };
          query.where = (f, op, val) => { query.filters.push([f, op, val]); return query; };
          query.orderBy = () => query;
          query.limit = (limit) => { query.max = limit; return query; };
          query.startAfter = () => query;
          query.get = async () => {
            const values = [...docs.entries()]
              .filter(([path]) => path.startsWith(`${name}/`))
              .map(([path, data]) => ({ id: path.split('/').pop(), data: () => data }))
              .filter((item) => query.filters.every(([key, , wanted]) => item.data()[key] === wanted));
            return { docs: values.slice(0, query.max) };
          };
          return query;
        },
      };
    },
    runTransaction: async (callback) => callback({
      get: async (reference) => ({ exists: docs.has(reference.path), data: () => docs.get(reference.path) }),
      set: (reference, data, options = {}) => {
        const previous = docs.get(reference.path) || {};
        docs.set(reference.path, options.merge ? { ...previous, ...data } : data);
      },
    }),
  };
}

const actor = { uid: 'u1', companyId: 'zawolf', active: true, capabilities: ['manage_policy_drafts'], grantIds: { manage_policy_drafts: ['g1'] }, grantVersionsById: { g1: 1 } };
const grant = { actorId: 'u1', companyId: 'zawolf', status: 'active', scopeType: 'company', scopeId: 'zawolf', capabilities: ['manage_policy_drafts'], version: 1 };

test('policy schema endpoint serves the server-owned schema to a scoped policy editor', async () => {
  const response = await handleRemotePolicyRequest({ db: fakeDb(), actor, method: 'GET', path: '/attendance/remote-work/policy-schema' });
  assert.equal(response.schemaVersion, 1);
  assert.ok(response.sections.some((section) => section.id === 'schedule'));
});

test('policy command route uses the actor company and rejects missing scope', async () => {
  const db = fakeDb({ 'remoteWorkCapabilityGrants/g1': grant });
  await assert.rejects(
    handleRemotePolicyRequest({ db, actor: { ...actor, capabilities: [], grantIds: {} }, method: 'POST', path: '/attendance/remote-work/policies/commands', body: { command: {
      operationId: 'unauthorized', kind: 'save_policy_draft', draftId: 'draft', expectedVersion: 0,
    } } }),
    (error) => error.code === 'not_authorized',
  );
  assert.equal(db.docs.has('attendancePolicyDrafts/zawolf_undefined'), false);
});

test('policy history is company scoped and bounded', async () => {
  const db = fakeDb({
    'attendancePolicyRevisions/zawolf_1': { companyId: 'zawolf', revision: 1, aggregate: { remoteWorkPolicy: { enabled: false } } },
    'attendancePolicyRevisions/other_1': { companyId: 'other', revision: 1, aggregate: { remoteWorkPolicy: { enabled: true } } },
  });
  const result = await handleRemotePolicyRequest({ db, actor, method: 'GET', path: '/attendance/remote-work/policies/history', query: { limit: '500' } });
  assert.deepEqual(result.items.map((item) => item.revision), [1]);
  assert.equal(result.nextCursor, null);
});

test('history revision identity round-trips into a revert command', async () => {
  const db = fakeDb({
    'remoteWorkCapabilityGrants/g1': grant,
    'attendancePolicyRevisions/zawolf_1': {
      companyId: 'zawolf', revision: 1, revisionId: '1', payloadHash: 'original',
      aggregate: { attendancePolicy: { defaultStartTime: '08:00' }, remoteWorkPolicy: { schemaVersion: 1, enabled: false } },
    },
  });
  const history = await handleRemotePolicyRequest({ db, actor, method: 'GET', path: '/attendance/remote-work/policies/history' });
  const revisionId = history.items[0].revisionId;
  const receipt = await handleRemotePolicyRequest({ db, actor, method: 'POST', path: '/attendance/remote-work/policies/commands', body: { command: {
    operationId: 'history-revert', kind: 'revert_policy', draftId: 'restored', expectedVersion: 0,
    payload: { targetRevisionId: revisionId, effectiveFrom: '2026-12-01T00:00:00Z' },
  } } });
  assert.equal(receipt.status, 'revert_draft_created');
  assert.equal(db.docs.get('attendancePolicyDrafts/zawolf_restored').aggregate.attendancePolicy.defaultStartTime, '08:00');
  assert.equal(db.docs.get('attendancePolicyDrafts/zawolf_restored').state, 'draft');
  assert.equal(db.docs.has('companies/zawolf'), false);
});

test('remote-work router dispatches /days to listRemoteDays query', async () => {
  const db = fakeDb({
    'attendance/u1_2026-11-02': {
      attendanceId: 'u1_2026-11-02',
      userId: 'u1',
      date: '2026-11-02',
      attendanceMode: 'remote_web',
      remoteSessionId: 'sess_01',
    },
  });
  const result = await handleRemotePolicyRequest({
    db,
    actor: { uid: 'u1', companyId: 'zawolf', active: true },
    method: 'GET',
    path: '/attendance/remote-work/days',
    query: { limit: '10' },
  });
  assert.ok(Array.isArray(result.items));
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].attendanceId, 'u1_2026-11-02');
});

