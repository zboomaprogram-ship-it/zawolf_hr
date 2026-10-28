'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryBackend } = require('./helpers/remote-work-fixtures');
const { executeRemotePolicyCommand } = require('../remote-work/policy-publication');
const { activateDuePolicyRevisions, queueDuePolicyActivations } = require('../remote-work/policy-activation');

const NOW = new Date('2026-11-01T00:00:00.000Z');
const DUE = new Date('2026-12-01T00:00:00.000Z');
function fixture(companyId = 'zawolf') {
  const backend = createMemoryBackend({ [`companies/${companyId}`]: {
    attendancePolicy: { defaultStartTime: '08:00', retiredRestriction: true }, securityPolicy: { keep: true },
  } });
  const actors = {};
  for (const [uid, capability] of [['editor', 'manage_policy_drafts'], ['reviewer', 'approve_policy'], ['publisher', 'publish_policy']]) {
    const id = `${companyId}_${uid}_grant`;
    backend.seed('remoteWorkCapabilityGrants', id, { companyId, actorId: uid, status: 'active',
      scopeType: 'company', scopeId: companyId, capabilities: [capability], version: 1 });
    actors[capability] = { uid, companyId, active: true, capabilities: [capability],
      grantIds: { [capability]: [id] }, grantVersionsById: { [id]: 1 } };
  }
  let sequence = 0;
  async function publish({ effectiveFrom = DUE.toISOString(), start = '10:00', now = NOW } = {}) {
    const draftId = `draft_${++sequence}`;
    const execute = (capability, command) => executeRemotePolicyCommand({ db: backend.db, actor: actors[capability], now, command });
    await execute('manage_policy_drafts', { operationId: `${draftId}_save`, kind: 'save_policy_draft', draftId, expectedVersion: 0,
      payload: { effectiveFrom, aggregate: { attendancePolicy: { defaultStartTime: start, extensionField: { keep: true } },
        remoteWorkPolicy: { schemaVersion: 1, enabled: false } } } });
    await execute('approve_policy', { operationId: `${draftId}_approve`, kind: 'approve_policy', draftId, expectedVersion: 1,
      payload: { decision: 'approved', reason: 'Independent review' } });
    return execute('publish_policy', { operationId: `${draftId}_publish`, kind: 'publish_policy', draftId, expectedVersion: 2,
      payload: { effectiveFrom } });
  }
  return { ...backend, publish, companyId };
}

test('future publication records the next activation time without changing active settings', async () => {
  const f = fixture();
  await f.publish();
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').nextActivationAt, DUE.toISOString());
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '08:00');
});

test('future policy cannot activate a millisecond before its effective instant', async () => {
  const f = fixture();
  await f.publish();
  const writesBefore = f.writes.length;
  const result = await activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: new Date(DUE.getTime() - 1) });
  assert.equal(result.status, 'not_due');
  assert.equal(f.writes.length, writesBefore);
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '08:00');
});

test('activation projects the immutable revision once and preserves unrelated settings', async () => {
  const f = fixture();
  await f.publish();
  const immutable = f.read('attendancePolicyRevisions', 'zawolf_1');
  const result = await activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: DUE });
  assert.equal(result.status, 'activated');
  assert.equal(result.activeRevision, 1);
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '10:00');
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.retiredRestriction, undefined);
  assert.deepEqual(f.read('companies', 'zawolf').securityPolicy, { keep: true });
  assert.deepEqual(f.read('companies', 'zawolf').attendancePolicy.extensionField, { keep: true });
  assert.deepEqual(f.read('attendancePolicyRevisions', 'zawolf_1'), immutable);
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').scheduledRevisions.length, 0);
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').nextActivationAt, null);
  const epoch = f.read('remoteWorkCalendarGuards', 'zawolf').epoch;
  const again = await activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: DUE });
  assert.equal(again.status, 'not_due');
  assert.equal(f.read('remoteWorkCalendarGuards', 'zawolf').epoch, epoch);
});

test('activation chooses latest effective time even when publication numbers run in reverse', async () => {
  const f = fixture();
  await f.publish({ effectiveFrom: '2026-12-02T00:00:00.000Z', start: '12:00' });
  await f.publish({ effectiveFrom: '2026-12-01T00:00:00.000Z', start: '09:00' });
  await activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: DUE });
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '09:00');
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').activeRevision, 2);
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').revision, 2);
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').nextActivationAt, '2026-12-02T00:00:00.000Z');
  await activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: new Date('2026-12-02T00:00:00.000Z') });
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '12:00');
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').activeRevision, 1);
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').revision, 2);
});

test('competing activations produce one transition and one guard increment', async () => {
  const f = fixture();
  await f.publish();
  const results = await Promise.all([
    activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: DUE }),
    activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: DUE }),
  ]);
  assert.deepEqual(results.map((result) => result.status).sort(), ['activated', 'not_due']);
  assert.equal(f.read('remoteWorkCalendarGuards', 'zawolf').epoch, 1);
});

for (const corruption of ['missing', 'company', 'time', 'payload']) {
  test(`invalid ${corruption} revision leaves company projection and head unchanged`, async () => {
    const f = fixture();
    await f.publish();
    const revision = f.read('attendancePolicyRevisions', 'zawolf_1');
    if (corruption === 'missing') f.documents.delete('attendancePolicyRevisions/zawolf_1');
    if (corruption === 'company') f.seed('attendancePolicyRevisions', 'zawolf_1', { ...revision, companyId: 'other' });
    if (corruption === 'time') f.seed('attendancePolicyRevisions', 'zawolf_1', { ...revision, effectiveFrom: '2026-12-02T00:00:00.000Z' });
    if (corruption === 'payload') f.seed('attendancePolicyRevisions', 'zawolf_1', { ...revision, aggregate: { attendancePolicy: { defaultStartTime: '21:00' }, remoteWorkPolicy: { schemaVersion: 1, enabled: false } } });
    const company = f.read('companies', 'zawolf');
    const head = f.read('attendancePolicyHeads', 'zawolf');
    await assert.rejects(activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: DUE }));
    assert.deepEqual(f.read('companies', 'zawolf'), company);
    assert.deepEqual(f.read('attendancePolicyHeads', 'zawolf'), head);
  });
}

test('publication rejects two revisions with the same effective instant', async () => {
  const f = fixture();
  await f.publish();
  await assert.rejects(f.publish({ start: '11:00' }), (error) => error.code === 'policy_effective_time_conflict');
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').revision, 1);
  assert.equal(f.count('attendancePolicyRevisions'), 1);
});

test('due activation worker bounds company discovery and isolates a failed company', async () => {
  const f = fixture();
  await f.publish();
  const calls = [];
  const db = {
    collection(name) {
      assert.equal(name, 'attendancePolicyHeads');
      const query = {
        where(field, op, value) { calls.push(['where', field, op, value]); return query; },
        orderBy(field) { calls.push(['orderBy', field]); return query; },
        limit(limit) { calls.push(['limit', limit]); return query; },
        async get() { return { docs: ['bad', 'zawolf'].map((id) => ({ id, data: () => f.read('attendancePolicyHeads', id) })) }; },
      };
      return query;
    },
    runTransaction: f.db.runTransaction,
  };
  // Delegate transaction references to the real memory backend.
  const scanDb = { ...db, collection(name) {
    if (name === 'attendancePolicyHeads') {
      const query = db.collection(name);
      return { ...query, doc: (id) => f.db.collection(name).doc(id) };
    }
    return f.db.collection(name);
  } };
  f.seed('attendancePolicyHeads', 'bad', { companyId: 'wrong', version: 1, nextActivationAt: DUE.toISOString(), scheduledRevisions: [{ revision: 9, revisionId: '9', effectiveFrom: DUE.toISOString() }] });
  const result = await queueDuePolicyActivations({ db: scanDb, now: DUE, pageSize: 2 });
  assert.deepEqual(calls.find((call) => call[0] === 'limit'), ['limit', 2]);
  assert.equal(result.scanned, 2);
  assert.equal(result.activated, 1);
  assert.equal(result.failed, 1);
  assert.equal(f.read('attendancePolicyHeads', 'bad').nextActivationAt, '2026-12-01T00:05:00.000Z');
  assert.equal(f.read('attendancePolicyHeads', 'bad').scheduledRevisions[0].effectiveFrom, DUE.toISOString());
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '10:00');
});

test('a delayed scheduled activation never overwrites a more recent immediate policy', async () => {
  const f = fixture();
  await f.publish();
  await f.publish({ now: new Date('2026-12-02T00:00:00.000Z'), effectiveFrom: '2026-12-02T00:00:00.000Z', start: '13:00' });
  const guard = f.read('remoteWorkCalendarGuards', 'zawolf');
  assert.equal(guard.epoch, 1);
  const result = await activateDuePolicyRevisions({ db: f.db, companyId: f.companyId, now: new Date('2026-12-02T01:00:00.000Z') });
  assert.equal(result.status, 'superseded');
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '13:00');
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').activeRevision, 2);
  assert.deepEqual(f.read('remoteWorkCalendarGuards', 'zawolf'), guard);
});
