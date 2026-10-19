'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { legacyHrAdvancePatch } = require('../advance-route-reconciliation');

test('an untouched unstaged advance becomes an actionable HR stage', () => {
  assert.deepEqual(legacyHrAdvancePatch({
    status: 'pending_manager', managerId: 'manager-uid', managerIds: ['manager-uid'],
  }), {
    status: 'pending_hr', advanceRouteStage: 'hr',
    managerId: 'HR', managerName: 'الموارد البشرية',
  });
});

test('explicit stages and manager-reviewed advances are never re-routed to HR', () => {
  assert.equal(legacyHrAdvancePatch({ status: 'pending_manager', advanceRouteStage: 'ceo' }), null);
  assert.equal(legacyHrAdvancePatch({ status: 'pending_manager', advanceRouteStage: 'accounting' }), null);
  assert.equal(legacyHrAdvancePatch({
    status: 'pending_manager', managerApprovalTrail: [{ reviewerId: 'manager-uid' }],
  }), null);
  assert.equal(legacyHrAdvancePatch({
    status: 'pending_manager', approvalHistory: [{ stage: 'manager', status: 'approved' }],
  }), null);
  assert.equal(legacyHrAdvancePatch({ status: 'pending_hr', managerId: 'HR' }), null);
});
