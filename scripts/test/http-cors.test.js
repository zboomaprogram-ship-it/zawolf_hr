'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  operationCorsHeaders,
  operationCorsHeaderValue,
} = require('../http-cors');

test('authenticated operation preflight allows the idempotency header', () => {
  assert.deepEqual(operationCorsHeaders, [
    'Authorization',
    'Content-Type',
    'X-Operation-Id',
    'X-Upload-Offset',
  ]);
  assert.match(operationCorsHeaderValue(), /X-Operation-Id/);
});
