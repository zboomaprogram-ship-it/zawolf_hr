const test = require('node:test');
const assert = require('node:assert/strict');
const { reserveWorkspaceOperation, completeWorkspaceOperation } = require('../workspace/operation-idempotency');
const { workspaceSafeError } = require('../workspace/safe-errors');

function fakeDb() {
  const documents = new Map();
  return {
    collection(name) {
      return { doc(id) {
        const key = `${name}/${id}`;
        return {
          async get() { const value = documents.get(key); return { exists: value != null, data: () => value }; },
          async create(value) { if (documents.has(key)) { const error = new Error('exists'); error.code = 'already_exists'; throw error; } documents.set(key, value); },
          async update(value) { documents.set(key, { ...documents.get(key), ...value }); },
        };
      } };
    },
  };
}

test('temporary provider failure remains a safe retryable pending result', async () => {
  const safe = workspaceSafeError({ statusCode: 503, message: 'provider token=private' }, { writeMayHaveStarted: true });
  assert.equal(safe.statusCode, 503);
  assert.equal(safe.retry, 'check_status');
  assert.equal(safe.error.includes('private'), false);
});

test('a completed operation replays its previous receipt after reconnect', async () => {
  const db = fakeDb();
  const input = { db, operationId: 'reconnect_operation_001', actorId: 'employee-1', resourceId: 'sheet-1' };
  const first = await reserveWorkspaceOperation(input);
  await completeWorkspaceOperation({ reservation: first, result: { state: 'acknowledged', safeMessage: 'تم الحفظ.' } });
  const retry = await reserveWorkspaceOperation(input);
  assert.equal(retry.kind, 'replay');
  assert.deepEqual(retry.receipt.state, 'acknowledged');
});
