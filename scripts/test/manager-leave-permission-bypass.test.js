const test = require('node:test');
const assert = require('node:assert/strict');

const {
  isEligiblePermissionCandidate,
  nextApprovalStage,
} = require('../manager-leave-permission-bypass');

test('manager leave bypass applies only to same-day time permissions', () => {
  const base = {
    requestDate: '2026-07-27',
    managerId: 'manager-1',
  };

  assert.equal(
    isEligiblePermissionCandidate(
      {...base, permissionType: 'late_arrival'},
      '2026-07-27',
    ),
    true,
  );
  assert.equal(
    isEligiblePermissionCandidate(
      {...base, permissionType: 'late_arrival'},
      '2026-07-28',
    ),
    false,
  );
  assert.equal(
    isEligiblePermissionCandidate(
      {...base, permissionType: 'annual_leave'},
      '2026-07-27',
    ),
    false,
  );
});

test('manager leave bypass continues to the next assigned manager', () => {
  assert.deepEqual(
    nextApprovalStage({
      managerIds: ['direct', 'higher'],
      managerId: 'direct',
      managerApprovalIndex: 0,
      requiresHrApproval: true,
    }),
    {
      status: 'pending_manager',
      managerId: 'higher',
      managerApprovalIndex: 1,
    },
  );
});

test('manager leave bypass continues to HR when policy requires HR', () => {
  assert.equal(
    nextApprovalStage({
      managerIds: ['direct'],
      managerId: 'direct',
      managerApprovalIndex: 0,
      requiresHrApproval: true,
    }).status,
    'pending_hr',
  );
});

test('manager leave bypass finalizes when HR is not required', () => {
  assert.equal(
    nextApprovalStage({
      managerIds: ['direct'],
      managerId: 'direct',
      managerApprovalIndex: 0,
      requiresHrApproval: false,
    }).status,
    'approved',
  );
});
