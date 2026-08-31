const test = require('node:test');
const assert = require('node:assert/strict');
const {
  reserveWorkspaceOperation,
  completeWorkspaceOperation,
} = require('../workspace/operation-idempotency');
const { workspaceSafeError } = require('../workspace/safe-errors');
const { appendWorkspaceAudit } = require('../workspace/audit');

function fakeDb() {
  const documents = new Map();
  return {
    documents,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            id,
            async get() {
              const value = documents.get(path);
              return { exists: value != null, data: () => value };
            },
            async create(value) {
              if (documents.has(path)) {
                const error = new Error('already exists');
                error.code = 'already_exists';
                throw error;
              }
              documents.set(path, value);
            },
            async update(value) {
              documents.set(path, { ...documents.get(path), ...value });
            },
          };
        },
      };
    },
  };
}

test('duplicate operation ID replays one receipt and never creates a second mutation', async () => {
  const db = fakeDb();
  const input = {
    db,
    operationId: 'stable_operation_0001',
    actorId: 'actor-1',
    resourceId: 'resource-1',
  };
  const first = await reserveWorkspaceOperation(input);
  assert.equal(first.kind, 'new');
  await completeWorkspaceOperation({
    reservation: first,
    result: { state: 'acknowledged', safeMessage: 'تم الحفظ.' },
  });

  const replay = await reserveWorkspaceOperation(input);
  assert.equal(replay.kind, 'replay');
  assert.equal(replay.receipt.state, 'acknowledged');
  assert.equal(db.documents.size, 1);
});

test('an operation ID cannot be replayed by another actor', async () => {
  const db = fakeDb();
  await reserveWorkspaceOperation({
    db,
    operationId: 'stable_operation_0002',
    actorId: 'actor-1',
    resourceId: 'resource-1',
  });

  await assert.rejects(
    reserveWorkspaceOperation({
      db,
      operationId: 'stable_operation_0002',
      actorId: 'actor-2',
      resourceId: 'resource-1',
    }),
    (error) => error.code === 'not_authorized',
  );
});

test('safe errors never return raw provider error strings', () => {
  const safe = workspaceSafeError(
    { statusCode: 503, message: 'FirebaseException: permission-denied token=secret' },
    { writeMayHaveStarted: true },
  );
  assert.equal(safe.statusCode, 503);
  assert.equal(safe.error.includes('Firebase'), false);
  assert.equal(safe.error.includes('secret'), false);
  assert.equal(safe.retry, 'check_status');
});

test('legacy forbidden resource errors preserve a safe access response', () => {
  const safe = workspaceSafeError({ code: 'forbidden', message: 'Google Drive ID xyz' });
  assert.equal(safe.statusCode, 403);
  assert.equal(safe.error.includes('Google'), false);
});

test('audit records only allowlisted non-sensitive details', async () => {
  const db = fakeDb();
  const event = await appendWorkspaceAudit({
    db,
    actorId: 'actor-1',
    resourceId: 'resource-1',
    action: 'sheet_edit',
    details: { range: 'Sheet1!A1:B2', changeCount: 2, token: 'do-not-store' },
  });

  assert.equal(event.details.range, 'Sheet1!A1:B2');
  assert.equal(event.details.token, undefined);
});
