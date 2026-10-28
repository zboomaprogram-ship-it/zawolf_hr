'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { enforceDayMode } = require('../remote-work/day-mode-guard');

test('enforceDayMode allows first check-in and locks the mode for that date', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:00:00.000Z',
    fixtures: {},
  });

  // 1. Initial remote check-in
  await harness.db.runTransaction(async (tx) => {
    const decision = await enforceDayMode({
      transaction: tx,
      db: harness.db,
      actorId: 'emp_001',
      date: '2026-11-02',
      requestedMode: 'remote_web',
      evidence: { verifiedProof: { credentialId: 'cred_1' } },
    });
    assert.equal(decision.allowed, true);
    assert.equal(decision.mode, 'remote_web');
    assert.equal(decision.existingRecord, false);

    // Commit attendance record as remote_web
    tx.set(harness.db.collection('attendance').doc('emp_001_2026-11-02'), {
      userId: 'emp_001',
      date: '2026-11-02',
      isRemote: true,
      attendanceMode: 'remote_web',
      version: 1,
    });
  });

  // 2. Subsequent on_site_mobile check-in on the same date is rejected with mode_locked
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'emp_001',
        date: '2026-11-02',
        requestedMode: 'on_site_mobile',
      });
    });
  }, (err) => {
    assert.equal(err.code, 'mode_locked');
    return true;
  });

  // 3. Subsequent legacy 'office' mode check-in on the same date is also rejected
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'emp_001',
        date: '2026-11-02',
        requestedMode: 'office',
      });
    });
  }, (err) => {
    assert.equal(err.code, 'mode_locked');
    return true;
  });

  // 4. Same mode check-in succeeds with existingRecord = true
  await harness.db.runTransaction(async (tx) => {
    const decision = await enforceDayMode({
      transaction: tx,
      db: harness.db,
      actorId: 'emp_001',
      date: '2026-11-02',
      requestedMode: 'remote_web',
      evidence: { verifiedProof: { credentialId: 'cred_1' } },
    });
    assert.equal(decision.allowed, true);
    assert.equal(decision.existingRecord, true);
    assert.equal(decision.mode, 'remote_web');
  });

  await harness.close();
});

test('enforceDayMode locks on_site_mobile and rejects remote_web check-in', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:00:00.000Z',
    fixtures: {
      'attendance/emp_002_2026-11-02': {
        userId: 'emp_002',
        date: '2026-11-02',
        isRemote: false,
        attendanceMode: 'on_site_mobile',
        version: 1,
      },
    },
  });

  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'emp_002',
        date: '2026-11-02',
        requestedMode: 'remote_web',
        evidence: { verifiedProof: { credentialId: 'cred_2' } },
      });
    });
  }, (err) => {
    assert.equal(err.code, 'mode_locked');
    return true;
  });

  await harness.close();
});

test('enforceDayMode validates inputs and proofs', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T08:00:00.000Z',
    fixtures: {},
  });

  // Invalid actor
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: '',
        date: '2026-11-02',
        requestedMode: 'remote_web',
      });
    });
  }, (err) => err.code === 'invalid_actor');

  // Invalid date
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'emp_003',
        date: 'invalid-date',
        requestedMode: 'remote_web',
      });
    });
  }, (err) => err.code === 'invalid_date');

  // Unknown mode
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'emp_003',
        date: '2026-11-02',
        requestedMode: 'hybrid_space',
      });
    });
  }, (err) => err.code === 'invalid_mode');

  // Remote check-in requires proof
  await assert.rejects(async () => {
    await harness.db.runTransaction(async (tx) => {
      await enforceDayMode({
        transaction: tx,
        db: harness.db,
        actorId: 'emp_003',
        date: '2026-11-02',
        requestedMode: 'remote_web',
        evidence: {},
      });
    });
  }, (err) => err.code === 'credential_unqualified');

  await harness.close();
});
