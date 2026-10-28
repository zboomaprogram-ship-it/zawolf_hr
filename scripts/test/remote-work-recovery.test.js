'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { declareRemoteIncident, resolveRemoteFinancialHold } = require('../remote-work/financial-holds');
const { correctRemoteDay } = require('../remote-work/recovery');

test('declareRemoteIncident seeds coverage and financial holds, and resolveRemoteFinancialHold resolves them', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T10:00:00.000Z',
    fixtures: {
      'attendance/u1_2026-11-02': {
        userId: 'u1',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        version: 1,
      },
      'attendance/u2_2026-11-02': {
        userId: 'u2',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        version: 1,
      },
    },
  });

  const itActor = {
    uid: 'it_lead',
    active: true,
    companyId: 'zawolf',
    capabilities: ['it_admin', 'declare_incident'],
  };

  const hrActor = {
    uid: 'hr_lead',
    active: true,
    companyId: 'zawolf',
    capabilities: ['hr_admin', 'resolve_hold'],
  };

  // 1. IT declares incident
  const incidentReceipt = await declareRemoteIncident({
    db: harness.db,
    admin: {},
    actor: itActor,
    command: {
      operationId: 'op_inc_001',
      kind: 'declare_incident',
      payload: {
        incidentId: 'inc_vpn_outage',
        startDate: '2026-11-02',
        endDate: '2026-11-02',
        reason: 'Company-wide VPN routing outage prevented remote connections.',
        affectedEmployees: ['u1', 'u2'],
      },
    },
    now: new Date('2026-11-02T10:05:00.000Z'),
  });

  assert.equal(incidentReceipt.status, 'recorded');
  assert.equal(incidentReceipt.incidentId, 'inc_vpn_outage');

  // Verify incident record
  const incidentDoc = await harness.read('remoteWorkIncidents', 'inc_vpn_outage');
  assert.equal(incidentDoc.status, 'active');
  assert.deepEqual(incidentDoc.affectedEmployees, ['u1', 'u2']);

  // Verify financial holds created
  const hold1 = await harness.read('remoteWorkFinancialHolds', 'u1_2026-11-02');
  assert.equal(hold1.open, true);
  assert.equal(hold1.incidentId, 'inc_vpn_outage');

  // 2. IT actor CANNOT resolve financial hold (HR only)
  await assert.rejects(async () => {
    await resolveRemoteFinancialHold({
      db: harness.db,
      admin: {},
      actor: itActor,
      command: {
        operationId: 'op_resolve_fail',
        kind: 'resolve_hold',
        payload: {
          attendanceId: 'u1_2026-11-02',
          resolutionReason: 'Trying to resolve without HR capability',
        },
      },
      now: new Date('2026-11-02T11:00:00.000Z'),
    });
  }, (err) => err.code === 'not_authorized');

  // 3. HR actor resolves financial hold
  const resolveReceipt = await resolveRemoteFinancialHold({
    db: harness.db,
    admin: {},
    actor: hrActor,
    command: {
      operationId: 'op_resolve_001',
      kind: 'resolve_hold',
      payload: {
        attendanceId: 'u1_2026-11-02',
        resolutionReason: 'Approved as excusable technical outage without deduction.',
      },
    },
    now: new Date('2026-11-02T11:30:00.000Z'),
  });

  assert.equal(resolveReceipt.status, 'recorded');

  const resolvedHold1 = await harness.read('remoteWorkFinancialHolds', 'u1_2026-11-02');
  assert.equal(resolvedHold1.open, false);
  assert.equal(resolvedHold1.resolvedBy, 'hr_lead');

  // 4. Idempotent replay of hold resolution
  const resolveRetry = await resolveRemoteFinancialHold({
    db: harness.db,
    admin: {},
    actor: hrActor,
    command: {
      operationId: 'op_resolve_001',
      kind: 'resolve_hold',
      payload: {
        attendanceId: 'u1_2026-11-02',
        resolutionReason: 'Approved as excusable technical outage without deduction.',
      },
    },
    now: new Date('2026-11-02T11:35:00.000Z'),
  });
  assert.equal(resolveRetry.status, 'already_recorded');

  await harness.close();
});

test('correctRemoteDay allows HR to adjust attendance times with audit trail', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T18:00:00.000Z',
    fixtures: {
      'attendance/u1_2026-11-02': {
        userId: 'u1',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        checkInTime: '2026-11-02T08:00:00.000Z',
        checkOutTime: null,
        version: 1,
      },
    },
  });

  const hrActor = {
    uid: 'hr_manager',
    active: true,
    companyId: 'zawolf',
    capabilities: ['hr_admin', 'attendance_correction'],
  };

  const correctReceipt = await correctRemoteDay({
    db: harness.db,
    admin: {},
    actor: hrActor,
    command: {
      operationId: 'op_correct_001',
      kind: 'correct_day',
      payload: {
        attendanceId: 'u1_2026-11-02',
        checkOutTime: '2026-11-02T17:00:00.000Z',
        correctionReason: 'Employee completed shift; connection dropped at checkout time.',
      },
    },
    now: new Date('2026-11-02T18:05:00.000Z'),
  });

  assert.equal(correctReceipt.status, 'recorded');
  assert.equal(correctReceipt.version, 2);

  const att = await harness.read('attendance', 'u1_2026-11-02');
  assert.equal(att.checkOutTime, '2026-11-02T17:00:00.000Z');
  assert.equal(att.manuallyCorrected, true);
  assert.equal(att.correctedBy, 'hr_manager');

  await harness.close();
});
