'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluateRemoteEligibility, isoWeekday, weekStartDate, weekEndDate, isRemoteAlias } = require('../remote-work/eligibility');
const { canonicalizeLegacyKind, classifyLegacyLeave } = require('../remote-work/legacy-authorization');

const policy = (overrides = {}) => ({
  enabled: true,
  eligibility: { weekStartDay: 6, daysPerWeek: 1, allowedWeekdays: [6, 7, 1, 2, 3, 4], probationEligible: false },
  ...overrides,
});

test('eligibility uses configured Saturday-Friday weeks and allowance', () => {
  assert.equal(isoWeekday('2026-11-02'), 1);
  assert.equal(weekStartDate('2026-11-02', 6), '2026-10-31');
  assert.equal(weekEndDate('2026-11-02', 6), '2026-11-06');
  const result = evaluateRemoteEligibility({
    employee: { isActive: true },
    policy: policy(),
    date: '2026-11-02',
    schedules: [{ id: 'tuesday', status: 'approved', date: '2026-11-03' }],
  });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, 'weekly_allowance_conflict');
});

test('real leave, holiday, rest day and probation override remote authorization', () => {
  const common = {
    employee: { isActive: true, isProbation: true },
    policy: policy({ eligibility: { ...policy().eligibility, probationEligible: true } }),
    date: '2026-11-02',
    schedules: [{ id: 'approved', status: 'approved', date: '2026-11-02' }],
  };
  assert.equal(evaluateRemoteEligibility({ ...common, leaves: [{ status: 'approved', leaveType: 'annual', date: common.date }] }).reason, 'approved_leave');
  assert.equal(evaluateRemoteEligibility({ ...common, holidays: [{ date: common.date }] }).reason, 'company_holiday');
  assert.equal(evaluateRemoteEligibility({ ...common, restDates: [common.date] }).reason, 'employee_rest_day');
  assert.equal(evaluateRemoteEligibility({ ...common, policy: policy() }).reason, 'probation_ineligible');
});

test('all supported legacy labels classify as remote aliases', () => {
  for (const value of ['remote', 'wfh', 'عمل عن بعد', 'يوم عمل عن بعد']) assert.equal(isRemoteAlias(value), true);
  assert.equal(isRemoteAlias('annual'), false);
});

test('legacy remote approvals activate only prospectively and converted unpaid entries require review', () => {
  for (const alias of ['remote', 'wfh', 'عمل عن بعد', 'يوم عمل عن بعد']) {
    assert.equal(canonicalizeLegacyKind(alias), 'remote_authorization');
  }
  assert.equal(canonicalizeLegacyKind('annual'), 'leave');
  assert.deepEqual(classifyLegacyLeave({
    leave: { leaveType: 'wfh', status: 'approved', startDate: '2026-11-03' },
    pilotEnabled: true,
    activationDate: '2026-11-01',
  }).kind, 'remote_authorization');
  assert.equal(classifyLegacyLeave({
    leave: { leaveType: 'unpaid', originalLeaveType: 'remote', status: 'approved', startDate: '2026-11-03' },
    pilotEnabled: true,
    activationDate: '2026-11-01',
  }).kind, 'converted_remote_leave');
  assert.equal(classifyLegacyLeave({
    leave: { leaveType: 'remote', status: 'approved', startDate: '2026-10-01' },
    pilotEnabled: true,
    activationDate: '2026-11-01',
  }).kind, 'historical_remote_leave');
});

test('approved authorization cannot bypass the published weekly allowance', () => {
  const result = evaluateRemoteEligibility({
    employee: { isActive: true }, policy: policy(), date: '2026-11-02',
    schedules: [
      { id: 'monday', status: 'approved', date: '2026-11-02' },
      { id: 'tuesday', status: 'approved', date: '2026-11-03' },
    ],
  });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, 'weekly_allowance_conflict');
});

test('a multi-date schedule authorizes its selected date and counts only that week', () => {
  const result = evaluateRemoteEligibility({
    employee: { isActive: true }, policy: policy(), date: '2026-11-02',
    schedules: [{ id: 'weekly', status: 'approved', dates: ['2026-11-02', '2026-11-09'] }],
  });
  assert.equal(result.eligible, true);
  assert.equal(result.authorizationId, 'weekly');
  assert.deepEqual(result.usedDates, ['2026-11-02']);
});

test('an approved replacement swaps the date instead of consuming another allowance', () => {
  const input = {
    employee: { isActive: true }, policy: policy(),
    schedules: [{ id: 'usual_monday', status: 'approved', date: '2026-11-02' }],
    datedAuthorizations: [{ id: 'replace', status: 'approved', date: '2026-11-03', replacesDate: '2026-11-02' }],
  };
  const replacement = evaluateRemoteEligibility({ ...input, date: '2026-11-03' });
  assert.equal(replacement.eligible, true);
  assert.equal(replacement.authorizationId, 'replace');
  assert.deepEqual(replacement.usedDates, ['2026-11-03']);
  const original = evaluateRemoteEligibility({ ...input, date: '2026-11-02' });
  assert.equal(original.eligible, false);
  assert.equal(original.reason, 'weekly_allowance_conflict');
});

test('invalid calendar dates reject without throwing from the date parser', () => {
  for (const date of ['2026-99-01', '2026-01-99', '2026-02-30']) {
    const result = evaluateRemoteEligibility({ employee: { isActive: true }, policy: policy(), date });
    assert.deepEqual(result, { eligible: false, reason: 'invalid_date' });
  }
});

test('an allowed weekday without an approved schedule or authorization is not eligible for attendance', () => {
  const result = evaluateRemoteEligibility({ employee: { isActive: true, companyId: 'zawolf' }, companyId: 'zawolf', policy: policy(), date: '2026-11-02' });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, 'authorization_required');
});

test('effective-dated recurring schedules authorize only their approved weekdays', () => {
  const input = { employee: { isActive: true, companyId: 'zawolf' }, companyId: 'zawolf', policy: policy(),
    schedules: [{ id: 'monday_schedule', status: 'approved', startDate: '2026-10-01', endDate: '2026-12-31', weekdays: [1] }] };
  const monday = evaluateRemoteEligibility({ ...input, date: '2026-11-02' });
  assert.equal(monday.eligible, true);
  assert.equal(monday.authorizationId, 'monday_schedule');
  assert.deepEqual(monday.usedDates, ['2026-11-02']);
  const tuesday = evaluateRemoteEligibility({ ...input, date: '2026-11-03' });
  assert.equal(tuesday.eligible, false);
});

test('overlapping approved recurring schedules are rejected explicitly', () => {
  const result = evaluateRemoteEligibility({ employee: { isActive: true }, policy: policy(), date: '2026-11-02', schedules: [
    { id: 'one', status: 'approved', startDate: '2026-10-01', endDate: '2026-12-31', weekdays: [1] },
    { id: 'two', status: 'approved', startDate: '2026-11-01', endDate: '2026-11-30', weekdays: [1] },
  ] });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, 'schedule_overlap');
});

test('a company mismatch denies eligibility and malformed policy fails safely', () => {
  const common = { employee: { isActive: true, companyId: 'other' }, companyId: 'zawolf', date: '2026-11-02', policy: policy() };
  assert.equal(evaluateRemoteEligibility(common).reason, 'wrong_company');
  const malformed = evaluateRemoteEligibility({ ...common, employee: { isActive: true, companyId: 'zawolf' },
    policy: policy({ eligibility: { weekStartDay: 9, daysPerWeek: 1, allowedWeekdays: [1], probationEligible: false } }) });
  assert.equal(malformed.eligible, false);
  assert.equal(malformed.reason, 'policy_configuration_invalid');
});

test('approved range authorizations count all covered days against the weekly allowance', () => {
  const result = evaluateRemoteEligibility({ employee: { isActive: true }, policy: policy(), date: '2026-11-02',
    datedAuthorizations: [{ id: 'legacy_range', status: 'approved', startDate: '2026-11-02', endDate: '2026-11-03' }] });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, 'weekly_allowance_conflict');
  assert.deepEqual(result.usedDates, ['2026-11-02', '2026-11-03']);
});
