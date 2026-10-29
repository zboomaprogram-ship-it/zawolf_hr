const test = require('node:test');
const assert = require('node:assert/strict');
const { resolveActorScope } = require('../remote-work/authorization');

function fakeDb({ user, grants = [] }) {
  const filters = [];
  const query = {
    where(field, operator, value) {
      filters.push([field, operator, value]);
      return this;
    },
    limit(value) { this.max = value; return this; },
    async get() {
      let found = grants;
      for (const [field, operator, value] of filters) {
        assert.equal(operator, '==');
        found = found.filter((grant) => grant[field] === value);
      }
      return { docs: found.slice(0, this.max).map((data) => ({ data: () => data })) };
    },
  };
  return {
    grantQuery: query,
    collection(name) {
      if (name === 'users') return { doc: (id) => ({ get: async () => ({ exists: id === 'u1' && !!user, data: () => user }) }) };
      if (name === 'remoteWorkCapabilityGrants') return query;
      throw new Error(`unexpected collection ${name}`);
    },
  };
}

const grant = (overrides = {}) => ({
  companyId: 'zawolf', actorId: 'u1', status: 'active', scopeType: 'company', scopeId: 'zawolf',
  capabilities: ['manage_policy_drafts', 'publish_policy'], version: 2,
  effectiveFrom: '2026-01-01T00:00:00.000Z', effectiveUntil: null,
  ...overrides,
});

test('actor scope uses active explicit capability grants and immutable grant version', async () => {
  const db = fakeDb({ user: { isActive: true, role: 'manager' }, grants: [grant()] });
  const result = await resolveActorScope({ db, identity: { uid: 'u1' }, requestedCompanyId: 'zawolf', now: new Date('2026-10-26T00:00:00Z') });
  assert.deepEqual(result.capabilities, ['manage_policy_drafts', 'publish_policy']);
  assert.equal(result.companyId, 'zawolf');
  assert.equal(result.grantVersions['manage_policy_drafts'], 2);
});

test('role labels do not grant remote capability and revoked or expired grants are ignored', async () => {
  const db = fakeDb({
    user: { isActive: true, companyId: 'zawolf', role: 'super_admin' },
    grants: [
      grant({ capabilities: ['approve_policy'], status: 'revoked' }),
      grant({ capabilities: ['publish_policy'], effectiveUntil: '2026-10-01T00:00:00Z' }),
    ],
  });
  const result = await resolveActorScope({ db, identity: { uid: 'u1' }, requestedCompanyId: 'zawolf', now: new Date('2026-10-26T00:00:00Z') });
  assert.deepEqual(result.capabilities, []);
});

test('actor cannot request a company outside its explicit membership', async () => {
  const db = fakeDb({ user: { isActive: true, companyId: 'zawolf' }, grants: [grant()] });
  await assert.rejects(
    resolveActorScope({ db, identity: { uid: 'u1' }, requestedCompanyId: 'another-company', now: new Date() }),
    (error) => error.code === 'wrong_company',
  );
});

test('active account without company membership or a scoped grant is rejected', async () => {
  const db = fakeDb({ user: { isActive: true, role: 'super_admin' } });
  await assert.rejects(
    resolveActorScope({ db, identity: { uid: 'u1' }, requestedCompanyId: 'zawolf', now: new Date() }),
    (error) => error.code === 'wrong_company',
  );
});

test('admin account bootstraps capabilities when live Firestore collection supports document writes', async () => {
  const written = {};
  const query = {
    where() { return this; },
    limit() { return this; },
    async get() { return { docs: [] }; },
    doc(id) {
      return {
        async set(data) {
          written[id] = data;
        },
      };
    },
  };
  const db = {
    collection(name) {
      if (name === 'users') return { doc: () => ({ get: async () => ({ exists: true, data: () => ({ isActive: true, role: 'hr_admin' }) }) }) };
      if (name === 'remoteWorkCapabilityGrants') return query;
      throw new Error(`unexpected collection ${name}`);
    },
  };
  const result = await resolveActorScope({ db, identity: { uid: 'admin_1' }, requestedCompanyId: 'zawolf', now: new Date('2026-10-29T12:00:00Z') });
  assert.equal(result.companyId, 'zawolf');
  assert.ok(result.capabilities.includes('manage_policy_drafts'));
  assert.ok(result.capabilities.includes('approve_policy'));
  assert.ok(result.capabilities.includes('publish_policy'));
  assert.ok(written['bootstrap_zawolf_admin_1']);
});

