'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  safeFailure,
  safeListEnvelope,
  redactPrivateFields,
  validatePageLimit,
  validateOperationEnvelope,
} = require('../company-os/safe-errors');

test('operation and list envelopes are bounded and provider safe', () => {
  assert.equal(validateOperationEnvelope({ operationId: 'op-12345678' }).operationId, 'op-12345678');
  assert.equal(validatePageLimit('25'), 25);
  assert.throws(() => validatePageLimit('500'));
  assert.deepEqual(safeListEnvelope({ items: [{ id: '1' }], scope: 'self' }), {
    ok: true,
    items: [{ id: '1' }],
    nextCursor: null,
    appliedScope: 'self',
    appliedFilters: {},
  });
  const failure = safeFailure(new Error('Firebase token=secret'));
  assert.equal(JSON.stringify(failure).includes('Firebase'), false);
  assert.equal(JSON.stringify(failure).includes('secret'), false);
});

test('private fields are removed recursively before serialization', () => {
  const result = redactPrivateFields({
    id: 'ticket-1',
    privateNote: 'secret',
    token: 'secret-token',
    nested: { password: 'pw', title: 'visible' },
  });
  assert.deepEqual(result, { id: 'ticket-1', nested: { title: 'visible' } });
});

