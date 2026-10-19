'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { legacyHrAdvancePatch } = require('../advance-route-reconciliation');

test('legacy advance assigned to the HR placeholder becomes an actionable HR stage', () => {
  assert.deepEqual(legacyHrAdvancePatch({
    status: 'pending_manager', managerId: 'HR', managerIds: ['HR'],
  }), {
    status: 'pending_hr', advanceRouteStage: 'hr',
    managerId: 'HR', managerName: 'الموارد البشرية',
  });
});

test('actual manager, CEO, and accounting stages are never re-routed to HR', () => {
  assert.equal(legacyHrAdvancePatch({ status: 'pending_manager', managerId: 'manager-uid' }), null);
  assert.equal(legacyHrAdvancePatch({ status: 'pending_manager', managerId: 'HR', advanceRouteStage: 'ceo' }), null);
  assert.equal(legacyHrAdvancePatch({ status: 'pending_hr', managerId: 'HR' }), null);
});
