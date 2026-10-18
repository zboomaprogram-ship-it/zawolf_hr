'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { parseDay, operationKey, isHrUser, uniqueIds } = require('../casual-leave-submit');

test('casual leave accepts only canonical calendar dates', () => {
  assert.equal(parseDay('2026-10-13').toISOString(), '2026-10-13T00:00:00.000Z');
  assert.throws(() => parseDay('13/10/2026'), /تاريخ الإجازة/);
});

test('casual leave operation keys are deterministic and actor scoped', () => {
  assert.equal(operationKey('employee-a', 'operation-1'), operationKey('employee-a', 'operation-1'));
  assert.notEqual(operationKey('employee-a', 'operation-1'), operationKey('employee-b', 'operation-1'));
});

test('casual leave awareness targets active HR and deduplicates its route ids', () => {
  assert.equal(isHrUser({ role: 'hr_admin' }), true);
  assert.equal(isHrUser({ department: 'Human Resources' }), true);
  assert.equal(isHrUser({ role: 'manager', department: 'Sales' }), false);
  assert.deepEqual(uniqueIds(['manager-1', ' manager-1 ', '', 'manager-2']), [
    'manager-1',
    'manager-2',
  ]);
});
