'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { executeRemoteSessionCommand } = require('../remote-work/session-commands');
const { finalizeRemoteShift } = require('../remote-work/attendance-finalization');

test('executeRemoteSessionCommand handles save_plan, submit_update, and save_summary with versioning', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T09:00:00.000Z',
    fixtures: {
      'remoteWorkSessions/zawolf_sess_100': {
        sessionId: 'sess_100',
        companyId: 'zawolf',
        userId: 'u1',
        date: '2026-11-02',
        attendanceId: 'u1_2026-11-02',
        status: 'active',
        version: 1,
      },
    },
  });

  const actor = {
    uid: 'u1',
    active: true,
    companyId: 'zawolf',
  };

  // 1. Save Plan
  const planReceipt = await executeRemoteSessionCommand({
    db: harness.db,
    admin: {},
    actor,
    command: {
      operationId: 'op_plan_001',
      kind: 'save_plan',
      date: '2026-11-02',
      sessionId: 'sess_100',
      expectedVersion: 1,
      payload: {
        goals: ['Finish API documentation', 'Review pull requests', 'Deploy hotfix'],
      },
    },
    now: new Date('2026-11-02T09:05:00.000Z'),
  });

  assert.equal(planReceipt.status, 'recorded');
  assert.equal(planReceipt.version, 2);

  const sessionAfterPlan = await harness.read('remoteWorkSessions', 'zawolf_sess_100');
  assert.equal(sessionAfterPlan.version, 2);
  assert.deepEqual(sessionAfterPlan.plan, ['Finish API documentation', 'Review pull requests', 'Deploy hotfix']);

  // Idempotent retry of plan
  const planRetry = await executeRemoteSessionCommand({
    db: harness.db,
    admin: {},
    actor,
    command: {
      operationId: 'op_plan_001',
      kind: 'save_plan',
      date: '2026-11-02',
      sessionId: 'sess_100',
      expectedVersion: 1,
      payload: {
        goals: ['Finish API documentation', 'Review pull requests', 'Deploy hotfix'],
      },
    },
    now: new Date('2026-11-02T09:06:00.000Z'),
  });
  assert.equal(planRetry.status, 'already_recorded');
  assert.equal(planRetry.version, 2);

  // 2. Submit Update
  const updateReceipt = await executeRemoteSessionCommand({
    db: harness.db,
    admin: {},
    actor,
    command: {
      operationId: 'op_update_001',
      kind: 'submit_update',
      date: '2026-11-02',
      sessionId: 'sess_100',
      expectedVersion: 2,
      payload: {
        slotIndex: 1,
        updateText: 'Completed task 1 and started task 2 successfully.',
      },
    },
    now: new Date('2026-11-02T12:00:00.000Z'),
  });

  assert.equal(updateReceipt.status, 'recorded');
  assert.equal(updateReceipt.version, 3);

  const sessionAfterUpdate = await harness.read('remoteWorkSessions', 'zawolf_sess_100');
  assert.equal(sessionAfterUpdate.updates.length, 1);
  assert.equal(sessionAfterUpdate.updates[0].slotIndex, 1);

  // 3. Save Summary
  const summaryReceipt = await executeRemoteSessionCommand({
    db: harness.db,
    admin: {},
    actor,
    command: {
      operationId: 'op_summary_001',
      kind: 'save_summary',
      date: '2026-11-02',
      sessionId: 'sess_100',
      expectedVersion: 3,
      payload: {
        summaryText: 'All daily objectives completed on time today.',
      },
    },
    now: new Date('2026-11-02T16:30:00.000Z'),
  });

  assert.equal(summaryReceipt.status, 'recorded');
  assert.equal(summaryReceipt.version, 4);

  const finalSession = await harness.read('remoteWorkSessions', 'zawolf_sess_100');
  assert.equal(finalSession.summary, 'All daily objectives completed on time today.');

  await harness.close();
});

test('finalizeRemoteShift marks session and attendance completed or missing checkout', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T22:00:00.000Z',
    fixtures: {
      'attendance/u1_2026-11-02': {
        userId: 'u1',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        checkInTime: '2026-11-02T07:00:00.000Z',
        checkOutTime: '2026-11-02T15:30:00.000Z',
        remoteSessionId: 'sess_101',
        companyId: 'zawolf',
        version: 2,
      },
      'remoteWorkSessions/zawolf_sess_101': {
        sessionId: 'sess_101',
        companyId: 'zawolf',
        userId: 'u1',
        date: '2026-11-02',
        status: 'active',
        version: 2,
      },
      'attendance/u2_2026-11-02': {
        userId: 'u2',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        checkInTime: '2026-11-02T07:00:00.000Z',
        checkOutTime: null, // missing checkout
        remoteSessionId: 'sess_102',
        companyId: 'zawolf',
        version: 1,
      },
      'remoteWorkSessions/zawolf_sess_102': {
        sessionId: 'sess_102',
        companyId: 'zawolf',
        userId: 'u2',
        date: '2026-11-02',
        status: 'active',
        version: 1,
      },
    },
  });

  // Finalize u1 with checkout
  const res1 = await finalizeRemoteShift({
    db: harness.db,
    admin: {},
    attendanceId: 'u1_2026-11-02',
    now: new Date('2026-11-02T22:00:00.000Z'),
  });
  assert.equal(res1.status, 'finalized');
  assert.equal(res1.hasCheckOut, true);

  const att1 = await harness.read('attendance', 'u1_2026-11-02');
  assert.equal(att1.finalizedStatus, 'completed');

  // Finalize u2 without checkout
  const res2 = await finalizeRemoteShift({
    db: harness.db,
    admin: {},
    attendanceId: 'u2_2026-11-02',
    now: new Date('2026-11-02T22:00:00.000Z'),
  });
  assert.equal(res2.status, 'finalized');
  assert.equal(res2.hasCheckOut, false);

  const att2 = await harness.read('attendance', 'u2_2026-11-02');
  assert.equal(att2.finalizedStatus, 'missing_checkout_finalized');

  // Idempotent retry returns already_finalized
  const res1Retry = await finalizeRemoteShift({
    db: harness.db,
    admin: {},
    attendanceId: 'u1_2026-11-02',
    now: new Date('2026-11-02T22:05:00.000Z'),
  });
  assert.equal(res1Retry.status, 'already_finalized');

  await harness.close();
});

test('submit_update enforces checkpoint window and rejects expired submissions', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T12:00:00.000Z',
    fixtures: {
      'companies/zawolf': {
        name: 'ZaWolf',
        attendancePolicy: {
          remoteWorkPolicy: {
            enabled: true,
            schedule: {
              checkpoints: [
                { id: 'cp_1', label: 'متابعة الصباح', dueTime: '10:00', graceMinutes: 15 },
                { id: 'cp_2', label: 'متابعة الظهيرة', dueTime: '13:00', graceMinutes: 15 },
              ],
            },
          },
        },
      },
      'remoteWorkSessions/zawolf_sess_200': {
        sessionId: 'sess_200',
        companyId: 'zawolf',
        userId: 'u1',
        date: '2026-11-02',
        status: 'active',
        version: 1,
      },
    },
  });

  const actor = { uid: 'u1', active: true, companyId: 'zawolf' };

  // 1. Trying to submit cp_1 at 10:30 Cairo (which is past 10:00 + 15 min deadline) -> throws checkpoint_window_expired
  // Cairo is UTC+2, so 08:30 UTC = 10:30 Cairo
  await assert.rejects(
    executeRemoteSessionCommand({
      db: harness.db,
      admin: {},
      actor,
      command: {
        operationId: 'op_update_expired',
        kind: 'submit_update',
        date: '2026-11-02',
        sessionId: 'sess_200',
        expectedVersion: 1,
        payload: {
          checkpointId: 'cp_1',
          updateText: 'Late update should be rejected',
        },
      },
      now: new Date('2026-11-02T08:30:00.000Z'),
    }),
    (err) => {
      assert.equal(err.code, 'checkpoint_window_expired');
      assert.match(err.messageAr, /انتهت فترة السماح المحددة لنقطة المتابعة/);
      return true;
    }
  );

  // 2. Submitting cp_2 at 13:10 Cairo (11:10 UTC) which is within 13:00 + 15m grace window -> succeeds
  const validReceipt = await executeRemoteSessionCommand({
    db: harness.db,
    admin: {},
    actor,
    command: {
      operationId: 'op_update_valid',
      kind: 'submit_update',
      date: '2026-11-02',
      sessionId: 'sess_200',
      expectedVersion: 1,
      payload: {
        checkpointId: 'cp_2',
        updateText: 'On time checkpoint update',
      },
    },
    now: new Date('2026-11-02T11:10:00.000Z'),
  });

  assert.equal(validReceipt.status, 'recorded');
  assert.equal(validReceipt.version, 2);

  const updatedSession = await harness.read('remoteWorkSessions', 'zawolf_sess_200');
  assert.equal(updatedSession.updates.length, 1);
  assert.equal(updatedSession.updates[0].checkpointId, 'cp_2');

  await harness.close();
});

