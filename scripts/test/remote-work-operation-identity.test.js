'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { hashRemoteOperation } = require('../remote-work/operation-identity');
const command = { kind: 'check_in', date: '2026-11-02', operationId: 'op1', payload: { goal: 'work', details: { b: 2, a: 1 } } };
test('canonical identity remains stable across key ordering and new ephemeral proof', () => {
  const reordered = { ...command, payload: { details: { a: 1, b: 2 }, goal: 'work' }, proof: { assertion: 'another-assertion' } };
  assert.equal(hashRemoteOperation(command), hashRemoteOperation(reordered));
});
test('business changes alter the identity, including day, action and version', () => {
  const original = hashRemoteOperation(command);
  for (const change of [{ date: '2026-11-03' }, { kind: 'check_out' }, { expectedVersion: 1 }, { sessionId: 'session1' }, { payload: { goal: 'other' } }]) {
    assert.notEqual(hashRemoteOperation({ ...command, ...change }), original);
  }
});
test('operation ID identifies the receipt but does not alter its business hash', () => {
  assert.equal(hashRemoteOperation(command), hashRemoteOperation({ ...command, operationId: 'op2' }));
});
for (const invalid of [undefined, NaN, Infinity, 1n, () => {}, new Date(), { x: undefined }]) {
  test(`non-JSON payload ${String(invalid)} is rejected`, () => assert.throws(() => hashRemoteOperation({ ...command, payload: { invalid } })));
}
test('unknown action and invalid date are rejected', () => {
  assert.throws(() => hashRemoteOperation({ ...command, kind: 'arbitrary' }));
  assert.throws(() => hashRemoteOperation({ ...command, date: '2026-02-30' }));
});

test('sparse arrays, cyclic input, and oversized payloads are rejected', () => {
  const sparse = [1, ,];
  sparse.extra = 2;
  const cycle = {};
  cycle.self = cycle;
  for (const payload of [{ sparse }, cycle, { data: 'x'.repeat(65536) }]) {
    assert.throws(() => hashRemoteOperation({ ...command, payload }));
  }
});
