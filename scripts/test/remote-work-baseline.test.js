'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { assertEmulatorEnvironment, createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { cycleForKey, keyForDateParts } = require('../payroll-cycle');
const { approvedEarlyLeaveConsequenceFraction, pendingDeductionCount } = require('../monthly-tasks');
const { checkoutDisabledResult, normalizePolicy } = require('../checkout-policy');

test('remote harness rejects absent, remote and production Firestore targets', () => {
  for (const env of [
    {},
    { FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443', GCLOUD_PROJECT: 'zawolf-hr-system' },
    { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', GCLOUD_PROJECT: 'zawolf-hr-system' },
  ]) assert.throws(() => assertEmulatorEnvironment(env));
  assert.deepEqual(
    assertEmulatorEnvironment({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', GCLOUD_PROJECT: 'demo-remote-work' }),
    { host: '127.0.0.1:8080', projectId: 'demo-remote-work' },
  );
});

test('memory harness injects server time and commits serialized transactions', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T06:45:00.000Z',
    fixtures: { 'counter/day': { value: 0 } },
  });
  const ref = harness.db.collection('counter').doc('day');
  await Promise.all(Array.from({ length: 12 }, () => harness.db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    transaction.set(ref, { value: snapshot.data().value + 1 });
  })));
  assert.equal((await harness.read('counter', 'day')).value, 12);
  assert.equal(harness.advanceTo('2026-11-02T08:15:00.000Z').toISOString(), '2026-11-02T08:15:00.000Z');
  harness.registerCommand('clock_probe', async ({ now }) => now.toISOString());
  assert.equal(await harness.execute(harness.command('clock_probe')), '2026-11-02T08:15:00.000Z');
  await harness.close();
});

test('payroll cycle closes on the 25th and opens on the 26th', () => {
  assert.equal(keyForDateParts('2026', '10', '25'), '2026-10');
  assert.equal(keyForDateParts('2026', '10', '26'), '2026-11');
  assert.deepEqual(cycleForKey('2026-11'), {
    key: '2026-11',
    startDate: '2026-10-26',
    endDate: '2026-11-25',
    nextStartDate: '2026-11-26',
  });
});

test('pending review counts and approved early-leave consequences stay distinct', () => {
  const attendance = [
    { data: () => ({ salaryDeductionApprovalStatus: 'approved' }) },
    { data: () => ({ salaryDeductionApprovalStatus: 'pending_hr' }) },
    { data: () => ({ salaryDeductionApprovalStatus: 'rejected' }) },
  ];
  const permissions = [
    { data: () => ({ rejectionConsequence: { status: 'pending_hr' } }) },
    { data: () => ({ rejectionConsequence: { status: 'approved', dayFraction: 0.5 } }) },
  ];
  assert.equal(pendingDeductionCount(attendance, permissions), 2);
  assert.equal(approvedEarlyLeaveConsequenceFraction(permissions[1].data()), 0.5);
  assert.equal(approvedEarlyLeaveConsequenceFraction(permissions[0].data()), 0);
});

test('missing or disabled checkout policy never creates checkout evidence', () => {
  const policy = normalizePolicy(null);
  const result = checkoutDisabledResult({ attendanceId: 'employee_2026-11-02', policy });
  assert.equal(policy.enabled, false);
  assert.equal(result.status, 'checkout_disabled');
  assert.equal(result.attendanceId, 'employee_2026-11-02');
  assert.equal(Object.hasOwn(result, 'checkOutTime'), false);
});
