const test = require('node:test');
const assert = require('node:assert/strict');
const {
  calculateAnnualQuota,
  entitlementPeriodStart,
  shouldRenewEntitlement,
  isActiveUser,
} = require('../daily-tasks');

test('attendance processing treats a missing active flag as active', () => {
  assert.equal(isActiveUser({}), true);
  assert.equal(isActiveUser({ isActive: true }), true);
  assert.equal(isActiveUser({ isActive: false }), false);
});

test('annual entitlement uses completed service and age boundaries', () => {
  const on = new Date(Date.UTC(2026, 8, 15));
  assert.equal(calculateAnnualQuota({
    hiringDate: new Date(Date.UTC(2026, 0, 1)), asOfDate: on,
  }), 15);
  assert.equal(calculateAnnualQuota({
    hiringDate: new Date(Date.UTC(2025, 8, 15)), asOfDate: on,
  }), 21);
  assert.equal(calculateAnnualQuota({
    hiringDate: new Date(Date.UTC(2016, 8, 15)), asOfDate: on,
  }), 30);
  assert.equal(calculateAnnualQuota({
    hiringDate: new Date(Date.UTC(2026, 0, 1)),
    birthDate: new Date(Date.UTC(1976, 8, 15)),
    asOfDate: on,
  }), 30);
});

test('renewal never overwrites a current or probation entitlement balance', () => {
  assert.equal(shouldRenewEntitlement({
    currentPeriodKey: '2026-03-31', nextPeriodKey: '2026-03-31', probation: false,
  }), false);
  assert.equal(shouldRenewEntitlement({
    currentPeriodKey: '', nextPeriodKey: '2026-09-30', probation: false,
  }), false);
  assert.equal(shouldRenewEntitlement({
    currentPeriodKey: '2026-03-31', nextPeriodKey: '2026-09-30', probation: true,
  }), false);
  assert.equal(shouldRenewEntitlement({
    currentPeriodKey: '2025-03-31', nextPeriodKey: '2026-03-31', probation: false,
  }), true);
});

test('entitlement period preserves probation and anniversary boundaries', () => {
  const hired = new Date(Date.UTC(2026, 2, 31));
  const policy = { probationMonths: 6, renewalMode: 'anniversary' };
  const probation = entitlementPeriodStart(hired, new Date(Date.UTC(2026, 8, 29)), policy);
  assert.equal(probation.probation, true);
  const eligible = entitlementPeriodStart(hired, new Date(Date.UTC(2026, 8, 30)), policy);
  assert.equal(eligible.probation, false);
});
