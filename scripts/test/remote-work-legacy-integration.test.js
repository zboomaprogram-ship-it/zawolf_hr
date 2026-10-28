'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { classifyLegacyLeave, canonicalizeLegacyKind } = require('../remote-work/legacy-authorization');
const { evaluateRemoteEligibility } = require('../remote-work/eligibility');
const { enforceDayMode } = require('../remote-work/day-mode-guard');
const { finalizeRemoteShift } = require('../remote-work/attendance-finalization');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');

test('Legacy remote aliases classify as remote_authorization while real leaves remain real_leave', () => {
  const aliases = ['remote', 'wfh', 'work_from_home', 'عمل عن بعد', 'يوم عمل عن بعد'];
  for (const alias of aliases) {
    assert.equal(canonicalizeLegacyKind(alias), 'remote_authorization', `Expected ${alias} to canonicalize to remote_authorization`);

    const result = classifyLegacyLeave({
      leave: {
        leaveType: alias,
        status: 'approved',
        date: '2026-11-02',
        approvalHistory: [{ step: 'hr_approved', approver: 'hr_admin' }],
      },
      pilotEnabled: true,
      activationDate: '2026-11-01',
    });
    assert.equal(result.kind, 'remote_authorization');
    assert.equal(result.eligibleForAttendance, true);
    assert.equal(result.date, '2026-11-02');
  }

  // Real leaves remain real_leave
  for (const realLeaveType of ['annual', 'sick', 'casual', 'unpaid', 'exam']) {
    assert.equal(canonicalizeLegacyKind(realLeaveType), 'leave');
    const result = classifyLegacyLeave({
      leave: {
        leaveType: realLeaveType,
        status: 'approved',
        date: '2026-11-02',
      },
      pilotEnabled: true,
      activationDate: '2026-11-01',
    });
    assert.equal(result.kind, 'real_leave');
    assert.equal(result.eligibleForAttendance, false);
  }
});

test('Historical remote leaves predating pilot activation require HR review', () => {
  const result = classifyLegacyLeave({
    leave: {
      leaveType: 'remote',
      status: 'approved',
      date: '2026-10-15',
    },
    pilotEnabled: true,
    activationDate: '2026-11-01',
  });
  assert.equal(result.kind, 'historical_remote_leave');
  assert.equal(result.eligibleForAttendance, false);
  assert.equal(result.requiresReview, true);
});

test('Previously converted remote leaves (to unpaid) require HR review and are not auto-converted', () => {
  const result = classifyLegacyLeave({
    leave: {
      leaveType: 'unpaid',
      originalLeaveType: 'remote',
      status: 'approved',
      date: '2026-11-05',
    },
    pilotEnabled: true,
    activationDate: '2026-11-01',
  });
  assert.equal(result.kind, 'converted_remote_leave');
  assert.equal(result.eligibleForAttendance, false);
  assert.equal(result.requiresReview, true);
});

test('Weekly allowance conflict: two approved remote dates in one Cairo week', () => {
  const policy = {
    enabled: true,
    eligibility: {
      weekStartDay: 6, // Saturday
      daysPerWeek: 1, // Only 1 day per week allowed
      allowedWeekdays: [1, 2, 3, 4, 7], // Sun, Mon, Tue, Wed, Thu
    },
  };

  const employee = {
    uid: 'u1',
    companyId: 'zawolf',
    isActive: true,
    isProbation: false,
  };

  // 2026-11-02 is Monday, 2026-11-03 is Tuesday (same Saturday-Friday week)
  const schedules = [
    {
      id: 'sch_mon',
      status: 'approved',
      date: '2026-11-02',
      version: 1,
    },
  ];
  const datedAuthorizations = [
    {
      id: 'auth_tue',
      status: 'approved',
      date: '2026-11-03',
      version: 1,
    },
  ];

  // Evaluating Tuesday when Monday is already approved exceeds the 1-day allowance
  const evalResult = evaluateRemoteEligibility({
    employee,
    companyId: 'zawolf',
    policy,
    date: '2026-11-03',
    schedules,
    datedAuthorizations,
  });

  assert.equal(evalResult.eligible, false);
  assert.equal(evalResult.reason, 'weekly_allowance_conflict');
});

test('Single-mode day lock prevents switching between office and remote on same date', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:00:00.000Z',
    fixtures: {
      'attendance/u1_2026-11-02': {
        userId: 'u1',
        date: '2026-11-02',
        status: 'present',
        attendanceMode: 'office',
        mode: 'office',
        checkInTime: '2026-11-02T07:30:00.000Z',
      },
    },
  });

  // Attempting remote check-in after office check-in throws mode_locked
  await assert.rejects(
    async () => {
      await harness.db.runTransaction(async (transaction) => {
        await enforceDayMode({
          transaction,
          db: harness.db,
          actorId: 'u1',
          date: '2026-11-02',
          requestedMode: 'remote_web',
          evidence: { challengeId: 'ch_1' },
        });
      });
    },
    (err) => err.code === 'mode_locked'
  );
});

test('finalizeRemoteShift distinguishes completed vs missing-checkout finalization', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T22:00:00.000Z',
    fixtures: {
      'attendance/u1_2026-11-02': {
        userId: 'u1',
        date: '2026-11-02',
        status: 'present',
        attendanceMode: 'remote_web',
        remoteSessionId: 'sess_1',
        checkInTime: '2026-11-02T07:00:00.000Z',
        checkOutTime: null, // No checkout
      },
      'remoteWorkSessions/zawolf_sess_1': {
        sessionId: 'sess_1',
        userId: 'u1',
        date: '2026-11-02',
        status: 'active',
      },
    },
  });

  const receipt = await finalizeRemoteShift({
    db: harness.db,
    admin: {},
    attendanceId: 'u1_2026-11-02',
    now: new Date('2026-11-02T22:00:00.000Z'),
  });

  assert.equal(receipt.status, 'finalized');
  assert.equal(receipt.hasCheckOut, false);

  const att = await harness.read('attendance', 'u1_2026-11-02');
  assert.equal(att.finalizedStatus, 'missing_checkout_finalized');

  const sess = await harness.read('remoteWorkSessions', 'zawolf_sess_1');
  assert.equal(sess.status, 'finalized_without_checkout');
});
