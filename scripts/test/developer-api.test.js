const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../developer-api/common');

test('credential generation stores only a salted hash and validates its bearer form', () => {
  const credential = C.createCredential({
    name: 'Partner integration',
    scopes: ['directory.read'],
    expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
  });
  const parsed = C.parseBearerCredential(`Bearer ${credential.secret}`);
  assert.equal(parsed.clientId, credential.clientId);
  assert.notEqual(credential.record.secretHash, credential.secret);
  assert.equal(credential.record.scopes[0], 'directory.read');
  assert.throws(() => C.parseBearerCredential('Bearer firebase-id-token'), /Invalid integration credential/);
});

test('directory serializer allowlists fields and never exports sensitive profile data', () => {
  const result = C.serializeDirectoryUser('opaque-user', {
    employeeId: 'EMP-12', displayName: 'Amina', department: 'HR', position: 'Officer', managerId: 'mgr-1', isActive: true,
    email: 'private@example.test', baseMonthlySalary: 99999, notificationTokens: ['secret'], registeredAttendanceDeviceId: 'device', latitude: 30,
  });
  assert.deepEqual(result, {
    id: 'opaque-user', employeeId: 'EMP-12', displayName: 'Amina', department: 'HR', position: 'Officer', managerId: 'mgr-1', active: true,
  });
});

test('cursor is caller-bound and page limits are bounded', () => {
  const cursor = C.encodeCursor({ v: 1, name: 'Amina', id: 'user-1' }, 'caller-one');
  assert.deepEqual(C.decodeCursor(cursor, 'caller-one'), { v: 1, name: 'Amina', id: 'user-1' });
  assert.throws(() => C.decodeCursor(cursor, 'caller-two'), /Cursor is invalid/);
  assert.equal(C.parseLimit('100'), 100);
  assert.throws(() => C.parseLimit('101'), /Limit is invalid/);
});

test('rate limit is per integration/client network and resets after its window', () => {
  C.resetRateLimitsForTest();
  for (let i = 0; i < 60; i += 1) assert.equal(C.allowRequest({ clientId: 'c', ip: 'ip', now: 1000 }), true);
  assert.equal(C.allowRequest({ clientId: 'c', ip: 'ip', now: 1000 }), false);
  assert.equal(C.allowRequest({ clientId: 'c', ip: 'ip', now: 62_000 }), true);
});

test('unknown scopes and credentials outside their expiry policy are rejected', () => {
  assert.throws(() => C.createCredential({ name: 'x', scopes: ['payroll.read'], expiresAt: new Date(Date.now() + 1000).toISOString() }), /Unsupported developer API scope/);
  assert.throws(() => C.createCredential({ name: 'x', scopes: ['directory.read'], expiresAt: new Date(Date.now() - 1000).toISOString() }), /expiry must be in the future/);
});

function fakeCredentialDb(record) {
  return {
    collection(name) {
      assert.equal(name, 'developerApiClients');
      return {
        doc(id) {
          return {
            async get() {
              return { exists: id === record.clientId, data: () => record.data };
            },
          };
        },
      };
    },
  };
}

test('authentication rejects a revoked or expired client without revealing which condition failed', async () => {
  const credential = C.createCredential({ name: 'Partner', scopes: ['directory.read'], expiresAt: new Date(Date.now() + 60_000).toISOString() });
  const db = fakeCredentialDb({ clientId: credential.clientId, data: { ...credential.record, status: 'revoked' } });
  await assert.rejects(
    C.authenticateCredential({ db, authorization: `Bearer ${credential.secret}` }),
    (error) => error.code === 'unauthenticated' && error.statusCode === 401,
  );
});

test('authentication returns only an active unexpired integration client', async () => {
  const credential = C.createCredential({ name: 'Partner', scopes: ['directory.read'], expiresAt: new Date(Date.now() + 60_000).toISOString() });
  const db = fakeCredentialDb({ clientId: credential.clientId, data: credential.record });
  const authenticated = await C.authenticateCredential({ db, authorization: `Bearer ${credential.secret}` });
  assert.equal(authenticated.clientId, credential.clientId);
  assert.equal(authenticated.client.name, 'Partner');
});

const { listUsers } = require('../developer-api/router');

function fakeUsersDb(rows, calls) {
  const query = {
    where(...args) { calls.push(['where', ...args]); return this; },
    orderBy(...args) { calls.push(['orderBy', ...args]); return this; },
    limit(value) { calls.push(['limit', value]); return this; },
    startAfter(...args) { calls.push(['startAfter', ...args]); return this; },
    async get() { return { docs: rows.map((row) => ({ id: row.id, data: () => row.data })) }; },
  };
  return { collection(name) { assert.equal(name, 'users'); return query; } };
}

test('directory query is active-only, bounded, ordered, and allowlisted', async () => {
  const calls = [];
  const url = new URL('https://api.test/developer-api/v1/users?limit=2&department=IT');
  const result = await listUsers({
    db: fakeUsersDb([
      { id: 'u1', data: { isActive: true, displayName: 'A', department: 'IT', baseMonthlySalary: 100 } },
      { id: 'u2', data: { isActive: true, displayName: 'B', department: 'IT', notificationTokens: ['nope'] } },
    ], calls),
    auth: { client: { scopes: ['directory.read'] }, cursorKey: 'key' },
    url,
  });
  assert.deepEqual(calls, [
    ['where', 'isActive', '==', true], ['where', 'department', '==', 'IT'],
    ['orderBy', 'displayName'], ['orderBy', '__name__'], ['limit', 3],
  ]);
  assert.equal(result.data.length, 2);
  assert.equal('baseMonthlySalary' in result.data[0], false);
  assert.equal('notificationTokens' in result.data[1], false);
});

test('inactive directory records need their own scope before any query', async () => {
  await assert.rejects(
    listUsers({
      db: { collection() { throw new Error('must not query'); } },
      auth: { client: { scopes: ['directory.read'] }, cursorKey: 'key' },
      url: new URL('https://api.test/developer-api/v1/users?active=false'),
    }),
    (error) => error.code === 'scope_denied',
  );
});

test('an exact Hostinger environment credential grants only directory reads without a Firestore client record', async () => {
  const credential = C.createCredential({
    name: 'Environment integration',
    scopes: ['directory.read'],
    expiresAt: new Date(Date.now() + 60_000).toISOString(),
  });
  const authenticated = await C.authenticateCredential({
    db: { collection() { throw new Error('environment key must not query developerApiClients'); } },
    authorization: `Bearer ${credential.secret}`,
    environment: {
      ZAWOLF_DEVELOPER_API_SECRET: credential.secret,
      ZAWOLF_DEVELOPER_API_CLIENT_NAME: 'Partner directory sync',
    },
  });
  assert.equal(authenticated.source, 'environment');
  assert.equal(authenticated.clientId, credential.clientId);
  assert.deepEqual(authenticated.client.scopes, ['directory.read']);
  assert.equal(authenticated.client.name, 'Partner directory sync');
});
