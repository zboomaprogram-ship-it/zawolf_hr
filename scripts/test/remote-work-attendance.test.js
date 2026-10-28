'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { executeRemoteAttendance } = require('../remote-work/attendance-commands');
const { enforceDayMode } = require('../remote-work/day-mode-guard');
const { markVerifiedProof } = require('../remote-work/verified-proofs');
const { hashRemoteOperation } = require('../remote-work/operation-identity');

test('executeRemoteAttendance commits check_in, session, and receipt in one transaction', async () => {
  const checkInCommand = {
    operationId: 'op_checkin_001',
    kind: 'check_in',
    date: '2026-11-02',
    payload: {},
  };

  const payloadHash = hashRemoteOperation(checkInCommand);
  const proof = markVerifiedProof({
    challengeId: 'ch_001',
    credentialId: 'cred_001',
    verified: true,
    challenge: 'random_challenge_str',
  });

  checkInCommand.proof = proof;

  const harness = await createRemoteHarness({
    now: '2026-11-02T06:45:00.000Z',
    fixtures: {
      'remoteWorkChallenges/ch_001': {
        companyId: 'zawolf',
        actorId: 'u1',
        action: 'check_in',
        operationId: 'op_checkin_001',
        payloadHash,
        date: '2026-11-02',
        credentialId: 'cred_001',
        challenge: 'random_challenge_str',
        createdAt: '2026-11-02T06:44:00.000Z',
        ttlSeconds: 120,
        expiresAt: '2026-11-02T06:46:00.000Z',
        consumedAt: null,
        version: 1,
      },
    },
  });

  const actor = {
    uid: 'u1',
    active: true,
    companyId: 'zawolf',
  };

  // 1. Initial Check-in
  const receipt1 = await executeRemoteAttendance({
    db: harness.db,
    admin: {},
    actor,
    command: checkInCommand,
    now: new Date('2026-11-02T06:45:00.000Z'),
  });

  assert.equal(receipt1.status, 'recorded');
  assert.equal(receipt1.attendanceId, 'u1_2026-11-02');
  assert.equal(receipt1.mode, 'remote_web');
  assert.equal(receipt1.version, 1);

  // Verify attendance document written
  const attDoc = await harness.read('attendance', 'u1_2026-11-02');
  assert.equal(attDoc.attendanceMode, 'remote_web');
  assert.equal(attDoc.isRemote, true);
  assert.equal(attDoc.status, 'present');

  // Verify remote session written
  const sessionDoc = await harness.read('remoteWorkSessions', 'zawolf_u1_2026-11-02');
  assert.equal(sessionDoc.status, 'active');
  assert.equal(sessionDoc.attendanceId, 'u1_2026-11-02');

  // 2. Replay with same operationId returns idempotent receipt without second mutation
  const receipt2 = await executeRemoteAttendance({
    db: harness.db,
    admin: {},
    actor,
    command: checkInCommand,
    now: new Date('2026-11-02T06:50:00.000Z'),
  });

  assert.equal(receipt2.status, 'already_recorded');
  assert.equal(receipt2.attendanceId, receipt1.attendanceId);
  assert.equal(receipt2.sessionId, receipt1.sessionId);

  // Verify row count remained 1
  assert.equal(await harness.count('attendance'), 1);

  // 3. Second check-in with replayed consumed challenge fails with challenge_consumed
  await assert.rejects(async () => {
    await executeRemoteAttendance({
      db: harness.db,
      admin: {},
      actor,
      command: { ...checkInCommand, operationId: 'op_checkin_002' },
      now: new Date('2026-11-02T07:00:00.000Z'),
    });
  }, (err) => err.code === 'challenge_consumed');

  // Second check-in with fresh proof fails with already_checked_in
  const proof2 = markVerifiedProof({
    challengeId: 'ch_002',
    credentialId: 'cred_001',
    verified: true,
    challenge: 'random_challenge_2',
  });
  const checkInCommand2 = {
    operationId: 'op_checkin_003',
    kind: 'check_in',
    date: '2026-11-02',
    payload: {},
    proof: proof2,
  };
  const payloadHash2 = hashRemoteOperation(checkInCommand2);
  harness.seed('remoteWorkChallenges', 'ch_002', {
    companyId: 'zawolf',
    actorId: 'u1',
    action: 'check_in',
    operationId: 'op_checkin_003',
    payloadHash: payloadHash2,
    date: '2026-11-02',
    credentialId: 'cred_001',
    challenge: 'random_challenge_2',
    createdAt: '2026-11-02T06:59:00.000Z',
    ttlSeconds: 120,
    expiresAt: '2026-11-02T07:01:00.000Z',
    consumedAt: null,
    version: 1,
  });

  await assert.rejects(async () => {
    await executeRemoteAttendance({
      db: harness.db,
      admin: {},
      actor,
      command: checkInCommand2,
      now: new Date('2026-11-02T07:00:00.000Z'),
    });
  }, (err) => err.code === 'already_checked_in');

  // 4. Check out
  const checkOutCommand = {
    operationId: 'op_checkout_001',
    kind: 'check_out',
    date: '2026-11-02',
    sessionId: receipt1.sessionId,
    payload: {},
  };

  const checkOutReceipt = await executeRemoteAttendance({
    db: harness.db,
    admin: {},
    actor,
    command: checkOutCommand,
    now: new Date('2026-11-02T15:00:00.000Z'),
  });

  assert.equal(checkOutReceipt.status, 'recorded');
  assert.equal(checkOutReceipt.version, 2);

  const updatedSession = await harness.read('remoteWorkSessions', 'zawolf_u1_2026-11-02');
  assert.equal(updatedSession.status, 'completed');

  await harness.close();
});

test('executeRemoteAttendance rejects client backdating when date does not match server Cairo date', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T06:45:00.000Z',
    fixtures: {},
  });

  const actor = {
    uid: 'u10',
    active: true,
    companyId: 'zawolf',
  };

  const backdatedCommand = {
    operationId: 'op_backdated_001',
    kind: 'check_in',
    date: '2026-10-15', // Past date!
    payload: {},
  };

  await assert.rejects(async () => {
    await executeRemoteAttendance({
      db: harness.db,
      admin: {},
      actor,
      command: backdatedCommand,
      now: new Date('2026-11-02T06:45:00.000Z'),
    });
  }, (err) => err.code === 'invalid_date');

  await harness.close();
});

test('enforceDayMode locks day mode and rejects mid-day mode switching', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:00:00.000Z',
    fixtures: {
      'attendance/u2_2026-11-02': {
        userId: 'u2',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        version: 1,
      },
      'attendance/u3_2026-11-02': {
        userId: 'u3',
        date: '2026-11-02',
        attendanceMode: 'office',
        isRemote: false,
        version: 1,
      },
    },
  });

  // u2 is locked to remote_web -> office requested must fail with mode_locked
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'u2',
        date: '2026-11-02',
        requestedMode: 'office',
      });
    });
  }, (err) => err.code === 'mode_locked');

  // u3 is locked to office -> remote_web requested must fail with mode_locked
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'u3',
        date: '2026-11-02',
        requestedMode: 'remote_web',
        evidence: { verifiedProof: true },
      });
    });
  }, (err) => err.code === 'mode_locked');

  await harness.close();
});
