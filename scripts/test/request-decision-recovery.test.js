'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  managerIds,
  managerIndex,
  requestRefFor,
} = require('../request-decision-recovery');

test('recovery preserves the assigned sequential manager and never broadens the route', () => {
  const managers = managerIds({
    managerIds: ['direct-manager', 'higher-manager', 'direct-manager'],
    managerId: 'direct-manager',
  });
  assert.deepEqual(managers, ['direct-manager', 'higher-manager']);
  assert.equal(managerIndex({ managerApprovalIndex: 1 }, managers), 1);
  assert.equal(managerIndex({ managerId: 'higher-manager' }, managers), 1);
});

test('recovery accepts only leave and permission collections', () => {
  const db = { collection: (name) => ({ doc: (id) => ({ name, id }) }) };
  assert.deepEqual(requestRefFor(db, 'leaves', 'request_12345678'), {
    name: 'leaves', id: 'request_12345678',
  });
  assert.throws(
    () => requestRefFor(db, 'administrativeRequests', 'request_12345678'),
    /غير مدعوم/,
  );
});
