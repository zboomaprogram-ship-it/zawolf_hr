const test = require('node:test');
const assert = require('node:assert/strict');
const {
  earlyLeaveFraction,
  validateEarlyLeaveForCheckout,
  reconcileEarlyLeave,
  reviewEarlyLeaveConsequence,
  canReviewConsequence,
} = require('../early-leave-reconciliation');

test('one through four requested hours map to quarter-day increments', () => {
  assert.equal(earlyLeaveFraction(60), 0.25);
  assert.equal(earlyLeaveFraction(120), 0.5);
  assert.equal(earlyLeaveFraction(180), 0.75);
  assert.equal(earlyLeaveFraction(240), 1);
  assert.throws(() => earlyLeaveFraction(30), /invalid/);
});

test('checkout validation binds owner, execution date, status, and earliest time', () => {
  const common = {
    permissionId: 'p1', actorUid: 'u1', dateKey: '2026-09-16',
    normalEndTime: '17:00',
    permission: {
      userId: 'u1', permissionType: 'early_leave', requestDate: '2026-09-16',
      durationMinutes: 120, status: 'pending_manager',
    },
  };
  const accepted = validateEarlyLeaveForCheckout({
    ...common, eventTime: new Date('2026-09-16T12:00:00.000Z'), // 15:00 Cairo
  });
  assert.equal(accepted.potentialDayFraction, 0.5);
  assert.equal(accepted.isEarly, true);
  assert.throws(
    () => validateEarlyLeaveForCheckout({
      ...common, eventTime: new Date('2026-09-16T11:59:00.000Z'),
    }),
    (error) => error.code === 'early_checkout_too_early',
  );
  assert.throws(
    () => validateEarlyLeaveForCheckout({
      ...common, actorUid: 'u2', eventTime: new Date('2026-09-16T12:00:00.000Z'),
    }),
    (error) => error.code === 'early_leave_not_owned',
  );
});

function fakeAdmin(seed) {
  const docs = new Map(Object.entries(seed));
  const reference = (path) => ({ path });
  const snapshot = (path) => ({
    exists: docs.has(path), data: () => docs.get(path),
  });
  const db = {
    collection(name) {
      return { doc(id) { return reference(`${name}/${id}`); } };
    },
    async runTransaction(callback) {
      return callback({
        get: async (ref) => snapshot(ref.path),
        set(ref, value, options) {
          docs.set(ref.path, options?.merge ? { ...(docs.get(ref.path) || {}), ...value } : value);
        },
      });
    },
  };
  return {
    firestore: Object.assign(() => db, {
      FieldValue: { serverTimestamp: () => 'server-time' },
    }),
    docs,
  };
}

test('rejected used request creates one pending HR consequence across retries', async () => {
  const admin = fakeAdmin({
    'permissions/p1': {
      userId: 'u1', permissionType: 'early_leave', requestDate: '2026-09-16',
      durationMinutes: 120, status: 'rejected', reviewerComment: 'غير مناسب',
    },
    'attendance/u1_2026-09-16': {
      earlyLeaveCheckoutEvidence: {
        permissionId: 'p1', checkoutEventId: 'event-1', potentialDayFraction: 0.5,
      },
    },
    'users/u1': { baseMonthlySalary: 26000, salaryCurrency: 'EGP' },
  });
  const first = await reconcileEarlyLeave({ admin, permissionId: 'p1' });
  const second = await reconcileEarlyLeave({ admin, permissionId: 'p1' });
  assert.equal(first.status, 'consequence_pending_hr');
  assert.equal(second.status, 'consequence_pending_hr');
  const consequence = admin.docs.get('permissions/p1').rejectionConsequence;
  assert.equal(consequence.dayFraction, 0.5);
  assert.equal(consequence.amount, 500);
  assert.equal(consequence.status, 'pending_hr');
});

test('rejection without a linked checkout creates no consequence', async () => {
  const admin = fakeAdmin({
    'permissions/p2': {
      userId: 'u2', permissionType: 'early_leave', requestDate: '2026-09-16',
      durationMinutes: 60, status: 'rejected',
    },
  });
  assert.deepEqual(
    await reconcileEarlyLeave({ admin, permissionId: 'p2' }),
    { status: 'not_used' },
  );
  assert.equal(admin.docs.get('permissions/p2').rejectionConsequence, undefined);
});

test('HR review is independent from the rejected request status', async () => {
  const admin = fakeAdmin({
    'permissions/p3': {
      status: 'rejected',
      rejectionConsequence: {
        consequenceId: 'early_leave_rejection:p3', status: 'pending_hr', revision: 1,
      },
    },
  });
  const result = await reviewEarlyLeaveConsequence({
    admin, actor: { uid: 'hr1', role: 'hr_admin' }, permissionId: 'p3', decision: 'approved',
  });
  assert.equal(result.status, 'approved');
  assert.equal(admin.docs.get('permissions/p3').status, 'rejected');
  assert.equal(admin.docs.get('permissions/p3').rejectionConsequence.status, 'approved');
  assert.equal(
    admin.docs.get('auditLogs/early-leave-review-p3-2').action,
    'early_leave_rejection_consequence_reviewed',
  );
  assert.deepEqual(
    await reviewEarlyLeaveConsequence({
      admin, actor: { uid: 'hr1', role: 'hr_admin' }, permissionId: 'p3', decision: 'approved',
    }),
    result,
  );
});

test('legacy HR department account can review while a normal employee cannot', () => {
  assert.equal(canReviewConsequence({ role: 'employee', department: 'Human Resources' }), true);
  assert.equal(canReviewConsequence({ role: 'employee', department: 'Programming' }), false);
});

test('approval reverses only a pending rejection consequence', async () => {
  const admin = fakeAdmin({
    'permissions/p4': {
      userId: 'u4', permissionType: 'early_leave', requestDate: '2026-09-16',
      durationMinutes: 60, status: 'approved',
      rejectionConsequence: { consequenceId: 'early_leave_rejection:p4', status: 'pending_hr', revision: 1 },
    },
    'attendance/u4_2026-09-16': {
      salaryDeductionCode: 'late_quarter_day',
      earlyLeaveCheckoutEvidence: { permissionId: 'p4', potentialDayFraction: 0.25 },
    },
  });
  assert.deepEqual(await reconcileEarlyLeave({ admin, permissionId: 'p4' }), { status: 'authorized' });
  assert.equal(admin.docs.get('permissions/p4').rejectionConsequence.status, 'reversed');
  assert.equal(admin.docs.get('attendance/u4_2026-09-16').salaryDeductionCode, 'late_quarter_day');
});

test('late permission approval reverses an HR-approved matching consequence', async () => {
  const admin = fakeAdmin({
    'permissions/p5': {
      userId: 'u5', permissionType: 'early_leave', requestDate: '2026-09-16',
      durationMinutes: 120, status: 'approved',
      rejectionConsequence: {
        consequenceId: 'early_leave_rejection:p5', status: 'approved', revision: 2,
      },
    },
    'attendance/u5_2026-09-16': {
      salaryDeductionCode: 'late_quarter_day',
      earlyLeaveCheckoutEvidence: { permissionId: 'p5', potentialDayFraction: 0.5 },
    },
  });
  await reconcileEarlyLeave({ admin, permissionId: 'p5' });
  assert.equal(admin.docs.get('permissions/p5').rejectionConsequence.status, 'reversed');
  assert.equal(admin.docs.get('attendance/u5_2026-09-16').salaryDeductionCode, 'late_quarter_day');
});
