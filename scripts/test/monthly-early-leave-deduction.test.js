const test = require('node:test');
const assert = require('node:assert/strict');
const {
  approvedEarlyLeaveConsequenceFraction,
  pendingDeductionCount,
} = require('../monthly-tasks');

const doc = (value) => ({ data: () => value });

test('cycle payroll counts only HR-approved early-leave consequences', () => {
  assert.equal(approvedEarlyLeaveConsequenceFraction({
    rejectionConsequence: { status: 'pending_hr', dayFraction: 0.5 },
  }), 0);
  assert.equal(approvedEarlyLeaveConsequenceFraction({
    rejectionConsequence: { status: 'rejected', dayFraction: 0.5 },
  }), 0);
  assert.equal(approvedEarlyLeaveConsequenceFraction({
    rejectionConsequence: { status: 'approved', dayFraction: 0.5 },
  }), 0.5);
  assert.equal(approvedEarlyLeaveConsequenceFraction({
    rejectionConsequence: { status: 'reversed', dayFraction: 0.5 },
  }), 0);
});

test('cycle pending count includes independent early-leave HR reviews', () => {
  const count = pendingDeductionCount(
    [doc({ salaryDeductionApprovalStatus: 'pending_hr' })],
    [
      doc({ rejectionConsequence: { status: 'pending_hr' } }),
      doc({ rejectionConsequence: { status: 'approved' } }),
    ],
  );
  assert.equal(count, 2);
});
