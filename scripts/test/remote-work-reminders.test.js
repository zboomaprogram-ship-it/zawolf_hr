'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  queueRemoteWorkReminders,
  queueRemoteIncidentCoverage,
  isQuietHours,
} = require('../remote-work/reminders');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');

test('isQuietHours evaluates daytime and overnight quiet hours correctly', () => {
  // Disabled
  assert.equal(isQuietHours(23 * 60, { enabled: false }), false);

  // Overnight: 22:00 (1320) -> 07:00 (420)
  const config = { enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60 };
  assert.equal(isQuietHours(23 * 60, config), true, '23:00 is quiet hours');
  assert.equal(isQuietHours(3 * 60, config), true, '03:00 is quiet hours');
  assert.equal(isQuietHours(8 * 60, config), false, '08:00 is NOT quiet hours');
  assert.equal(isQuietHours(15 * 60, config), false, '15:00 is NOT quiet hours');
});

test('queueRemoteWorkReminders queues reminders for scheduled employees and skips checked-in', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:00:00.000Z',
    fixtures: {
      'companies/zawolf': {
        name: 'ZaWolf',
        attendancePolicy: {
          remoteWorkPolicy: {
            enabled: true,
            notifications: {
              enabled: true,
              quietHours: { enabled: false },
            },
          },
        },
      },
      // Employee 1: Scheduled, not checked in -> Should be queued
      'remoteWorkSchedules/sch_u1': {
        companyId: 'zawolf',
        employeeId: 'u1',
        status: 'approved',
      },
      // Employee 2: Scheduled, already checked in -> Should be skipped
      'remoteWorkSchedules/sch_u2': {
        companyId: 'zawolf',
        employeeId: 'u2',
        status: 'approved',
      },
      'attendance/u2_2026-11-02': {
        userId: 'u2',
        date: '2026-11-02',
        checkInTime: '2026-11-02T07:45:00.000Z',
        attendanceMode: 'remote_web',
      },
    },
  });

  const result1 = await queueRemoteWorkReminders({
    db: harness.db,
    admin: {},
    now: new Date('2026-11-02T08:00:00.000Z'),
  });

  assert.equal(result1.scanned, 2);
  assert.equal(result1.queued, 1);
  assert.equal(result1.skipped, 1);

  // Second run: Employee 1 already has reminder queued -> Should be skipped (idempotent)
  const result2 = await queueRemoteWorkReminders({
    db: harness.db,
    admin: {},
    now: new Date('2026-11-02T08:05:00.000Z'),
  });

  assert.equal(result2.queued, 0);
  assert.equal(result2.skipped, 2);
});

test('queueRemoteIncidentCoverage fanouts coverage and holds for active incident', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T10:00:00.000Z',
    fixtures: {
      'remoteWorkIncidents/inc_01': {
        companyId: 'zawolf',
        date: '2026-11-02',
        fanoutStatus: 'pending',
        reason: 'VPN Gateway down',
      },
      'remoteWorkSchedules/sch_u1': {
        companyId: 'zawolf',
        employeeId: 'u1',
        status: 'approved',
      },
    },
  });

  const result = await queueRemoteIncidentCoverage({
    db: harness.db,
    admin: {},
    now: new Date('2026-11-02T10:00:00.000Z'),
  });

  assert.equal(result.queued, 1);

  // Check coverage document was created
  const cov = await harness.read('remoteWorkIncidentCoverage', 'inc_01_u1');
  assert.equal(cov.status, 'covered');

  // Check financial hold was created
  const hold = await harness.read('remoteWorkFinancialHolds', 'hold_inc_01_u1');
  assert.equal(hold.open, true);
  assert.equal(hold.reason, 'it_incident_protection');

  // Incident status was set to completed
  const inc = await harness.read('remoteWorkIncidents', 'inc_01');
  assert.equal(inc.fanoutStatus, 'completed');
});

test('queueRemoteWorkReminders escalates missed checkpoint to manager and HR after grace period', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:30:00.000Z', // 10:30 Cairo (past 10:15 deadline)
    fixtures: {
      'companies/zawolf': {
        name: 'ZaWolf',
        attendancePolicy: {
          remoteWorkPolicy: {
            enabled: true,
            notifications: { enabled: true, quietHours: { enabled: false } },
            schedule: {
              checkpoints: [
                { id: 'cp_morning', label: 'متابعة الصباح', dueTime: '10:00', graceMinutes: 15 },
              ],
            },
          },
        },
      },
      'users/u_emp': {
        displayName: 'أحمد علي',
        directManagerId: 'u_mgr',
        isActive: true,
      },
      'users/u_mgr': {
        displayName: 'مدير أحمد',
        role: 'manager',
        isActive: true,
      },
      'users/u_hr': {
        displayName: 'مسؤول HR',
        role: 'hr',
        isActive: true,
      },
      'remoteWorkSchedules/sch_emp': {
        companyId: 'zawolf',
        employeeId: 'u_emp',
        status: 'approved',
      },
      'attendance/u_emp_2026-11-02': {
        userId: 'u_emp',
        date: '2026-11-02',
        checkInTime: '2026-11-02T07:00:00.000Z',
        remoteSessionId: 'sess_emp_today',
        attendanceMode: 'remote_web',
      },
      'remoteWorkSessions/zawolf_sess_emp_today': {
        sessionId: 'sess_emp_today',
        companyId: 'zawolf',
        userId: 'u_emp',
        date: '2026-11-02',
        status: 'active',
        updates: [], // No update submitted!
      },
    },
  });

  const scanResult = await queueRemoteWorkReminders({
    db: harness.db,
    admin: {},
    now: new Date('2026-11-02T08:30:00.000Z'),
  });

  assert.equal(scanResult.queued, 1);

  // Check escalation record
  const esc = await harness.read('remoteWorkEscalations', 'missed_cp_u_emp_2026-11-02_cp_morning');
  assert.equal(esc.userId, 'u_emp');
  assert.equal(esc.checkpointId, 'cp_morning');
  assert.equal(esc.managerId, 'u_mgr');

  // Check Manager received notification
  const mgrNotif = await harness.read(
    'notifications/u_mgr/items',
    'mgr_missed_cp_u_emp_2026-11-02_cp_morning'
  );
  assert.equal(mgrNotif.type, 'remote_missed_checkpoint');
  assert.match(mgrNotif.title, /نقطة متابعة فائتة/);
  assert.match(mgrNotif.body, /أحمد علي/);

  // Check HR received notification
  const hrNotif = await harness.read(
    'notifications/u_hr/items',
    'hr_missed_cp_u_emp_2026-11-02_cp_morning_u_hr'
  );
  assert.equal(hrNotif.type, 'remote_missed_checkpoint');
  assert.match(hrNotif.title, /مخالفة دوام عن بُعد/);

  // Second scan must be idempotent (no re-queuing)
  const secondScan = await queueRemoteWorkReminders({
    db: harness.db,
    admin: {},
    now: new Date('2026-11-02T08:35:00.000Z'),
  });
  assert.equal(secondScan.queued, 0);

  await harness.close();
});

