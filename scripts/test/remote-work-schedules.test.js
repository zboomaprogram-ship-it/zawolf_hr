'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateScheduleRevision, resolveWeeklyExceptionDates } = require('../remote-work/schedule-policy');
const { saveRemoteSchedule } = require('../remote-work/schedules');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');

const policy = (daysPerWeek = 1) => ({ enabled: true, eligibility: { weekStartDay: 6, daysPerWeek,
  allowedWeekdays: [6, 7, 1, 2, 3, 4], carryoverEnabled: false, carryoverCap: 0 },
  schedule: { startTime: '09:00', endTime: '17:00', checkInOpenTime: '08:45', endDayOffset: 0 } });
const schedule = (overrides = {}) => ({ employeeId: 'employee', startDate: '2026-11-01', endDate: '2026-12-31', weekdays: [1], ...overrides });
const exception = (overrides = {}) => ({ id: 'exception', date: '2026-11-03', kind: 'replacement', replacesDate: '2026-11-02', status: 'approved', approvalSnapshot: [{ actorId: 'hr', decision: 'approved' }], ...overrides });

test('schedule accepts policy-defined weekdays and rejects invalid or past ranges', () => {
  const context = { policy: policy(), today: '2026-10-31' };
  assert.deepEqual(validateScheduleRevision({ schedule: schedule(), ...context }), { valid: true, errors: [] });
  for (const bad of [schedule({ startDate: '2026-02-30' }), schedule({ startDate: '2026-10-30' }),
    schedule({ endDate: '2026-10-31' }), schedule({ weekdays: [5] }), schedule({ weekdays: [1, 1] })]) {
    assert.equal(validateScheduleRevision({ schedule: bad, ...context }).valid, false);
  }
});

test('schedule respects configurable allowance and rejects active overlapping revisions', () => {
  const value = schedule({ weekdays: [1, 2] });
  assert.equal(validateScheduleRevision({ schedule: value, policy: policy(1), today: '2026-10-31' }).valid, false);
  assert.equal(validateScheduleRevision({ schedule: value, policy: policy(2), today: '2026-10-31' }).valid, true);
  const result = validateScheduleRevision({ schedule: value, policy: policy(2), today: '2026-10-31', existingSchedules: [
    { id: 'existing', employeeId: 'employee', status: 'approved', startDate: '2026-11-30', endDate: '2027-01-01' },
  ] });
  assert.ok(result.errors.some((error) => error.code === 'schedule_overlap'));
});

test('resolved shift must have a valid opening, end and explicit overnight offset', () => {
  const invalid = [
    { startTime: '09:00', endTime: '08:00', checkInOpenTime: '08:45', endDayOffset: 0 },
    { startTime: '09:00', endTime: '17:00', checkInOpenTime: '10:00', endDayOffset: 0 },
    { startTime: '09:00', endTime: '17:00', checkInOpenTime: '08:45', endDayOffset: 2 },
  ];
  for (const shift of invalid) assert.equal(validateScheduleRevision({ schedule: schedule(), policy: { ...policy(), schedule: shift }, today: '2026-10-31' }).valid, false);
  const overnight = { startTime: '22:00', endTime: '06:00', checkInOpenTime: '21:30', endDayOffset: 1 };
  assert.equal(validateScheduleRevision({ schedule: schedule(), policy: { ...policy(), schedule: overnight }, today: '2026-10-31' }).valid, true);
});

test('approved replacement swaps a date and retains its original approval evidence', () => {
  const approved = exception();
  const result = resolveWeeklyExceptionDates({ weekStart: '2026-10-31', schedule: schedule(), policy: policy(), exceptions: [approved] });
  assert.deepEqual(result.dates, ['2026-11-03']);
  assert.deepEqual(result.appliedExceptions[0].approvalSnapshot, [{ actorId: 'hr', decision: 'approved' }]);
  assert.deepEqual(approved.approvalSnapshot, [{ actorId: 'hr', decision: 'approved' }]);
});

test('policy allowance controls multiple replacements and additions without hidden constants', () => {
  const exceptions = [exception(), exception({ id: 'add', date: '2026-11-04', kind: 'addition', replacesDate: null })];
  const rejected = resolveWeeklyExceptionDates({ weekStart: '2026-10-31', schedule: schedule(), policy: policy(1), exceptions });
  assert.equal(rejected.error, 'weekly_allowance_conflict');
  const allowed = resolveWeeklyExceptionDates({ weekStart: '2026-10-31', schedule: schedule(), policy: policy(2), exceptions });
  assert.deepEqual(allowed.dates, ['2026-11-03', '2026-11-04']);
});

test('pending exceptions cannot change a week and invalid approved entries fail closed', () => {
  const context = { weekStart: '2026-10-31', schedule: schedule(), policy: policy(2) };
  const pending = resolveWeeklyExceptionDates({ ...context, exceptions: [exception({ status: 'pending' })] });
  assert.deepEqual(pending.dates, ['2026-11-02']);
  for (const entries of [
    [exception(), exception({ date: '2026-11-04' })],
    [exception({ date: '2026-11-10' })],
    [exception({ replacesDate: '2026-11-01' })],
    [exception({ approvalSnapshot: [] })],
  ]) assert.ok(resolveWeeklyExceptionDates({ ...context, exceptions: entries }).error);
});

test('week boundaries and schedule ranges hold over year rollover', () => {
  const input = { weekStart: '2026-12-26', schedule: schedule({ startDate: '2026-12-01', endDate: '2027-01-31', weekdays: [1] }), policy: policy() };
  const result = resolveWeeklyExceptionDates({ ...input, exceptions: [exception({ date: '2026-12-29', replacesDate: '2026-12-28' })] });
  assert.deepEqual(result.dates, ['2026-12-29']);
  assert.equal(resolveWeeklyExceptionDates({ ...input, weekStart: '2026-12-27', exceptions: [] }).error, 'invalid_week');
});

test('a missing or forged replacement identifier cannot hide overlapping approved schedules', () => {
  for (const value of [schedule(), schedule({ replacesRevisionId: 'old' })]) {
    const old = { employeeId: 'employee', status: 'approved', startDate: '2026-11-15', endDate: '2026-12-01', ...(value.replacesRevisionId ? { id: 'old' } : {}) };
    const result = validateScheduleRevision({ schedule: value, policy: policy(), today: '2026-10-31', existingSchedules: [old] });
    assert.ok(result.errors.some((entry) => entry.code === 'schedule_overlap'));
  }
});

test('carryover is explicit, policy-capped and never inferred from a disabled rule', () => {
  const ctx = { weekStart: '2026-10-31', schedule: schedule(), policy: policy(), exceptions: [exception({ kind: 'addition', replacesDate: null })] };
  assert.equal(resolveWeeklyExceptionDates(ctx).error, 'weekly_allowance_conflict');
  assert.equal(resolveWeeklyExceptionDates({ ...ctx, carryoverDays: 1 }).error, 'carryover_invalid');
  const withCarryover = { ...ctx.policy, eligibility: { ...ctx.policy.eligibility, carryoverEnabled: true, carryoverCap: 1 } };
  assert.deepEqual(resolveWeeklyExceptionDates({ ...ctx, policy: withCarryover, carryoverDays: 1 }).dates, ['2026-11-02', '2026-11-03']);
  assert.equal(resolveWeeklyExceptionDates({ ...ctx, policy: withCarryover, carryoverDays: 2 }).error, 'carryover_invalid');
});

test('unapproved steps in exception evidence and invalid scheduled weekdays fail closed', () => {
  const ctx = { weekStart: '2026-10-31', schedule: schedule(), policy: policy(2) };
  const partial = exception({ approvalSnapshot: [{ actorId: 'manager', decision: 'approved' }, { actorId: 'hr', decision: 'pending' }] });
  assert.equal(resolveWeeklyExceptionDates({ ...ctx, exceptions: [partial] }).error, 'invalid_exception');
  assert.equal(resolveWeeklyExceptionDates({ ...ctx, schedule: schedule({ weekdays: [5] }), exceptions: [] }).error, 'policy_configuration_invalid');
});

test('malformed eligibility policies fail closed without throwing or granting dates', () => {
  const invalid = [
    { allowedWeekdays: 42 },
    { allowedWeekdays: [1, 1] },
    { allowedWeekdays: [1, 8] },
    { daysPerWeek: 7 },
  ];
  for (const change of invalid) {
    const badPolicy = { ...policy(), eligibility: { ...policy().eligibility, ...change } };
    assert.equal(validateScheduleRevision({ schedule: schedule(), policy: badPolicy, today: '2026-10-31' }).valid, false);
    assert.equal(resolveWeeklyExceptionDates({ weekStart: '2026-10-31', schedule: schedule(), policy: badPolicy }).error, 'policy_configuration_invalid');
  }
});

test('saveRemoteSchedule saves versioned schedule, advances guard epoch and replays idempotent receipt', async () => {
  const harness = await createRemoteHarness({
    now: '2026-10-31T10:00:00.000Z',
    fixtures: {
      'companies/zawolf': {
        name: 'ZaWolf',
        attendancePolicy: {
          remoteWorkPolicy: policy(2),
        },
      },
    },
  });

  const actor = {
    uid: 'manager_1',
    active: true,
    companyId: 'zawolf',
    capabilities: ['manage_schedules'],
  };

  const command = {
    operationId: 'op_sched_001',
    kind: 'save_schedule',
    payload: {
      schedule: {
        employeeId: 'emp_123',
        startDate: '2026-11-01',
        endDate: '2026-12-31',
        weekdays: [1, 2],
      },
    },
  };

  // 1. Initial save
  const receipt1 = await saveRemoteSchedule({
    db: harness.db,
    admin: {},
    actor,
    command,
    now: new Date('2026-10-31T10:00:00.000Z'),
  });

  assert.equal(receipt1.status, 'recorded');
  assert.equal(receipt1.version, 1);
  assert.ok(receipt1.scheduleId);

  // Verify schedule stored
  const storedSchedule = await harness.read('remoteWorkSchedules', receipt1.scheduleId);
  assert.equal(storedSchedule.employeeId, 'emp_123');
  assert.equal(storedSchedule.status, 'approved');
  assert.deepEqual(storedSchedule.weekdays, [1, 2]);

  // Verify calendar guard epoch
  const guard = await harness.read('remoteWorkCalendarGuards', 'zawolf');
  assert.equal(guard.epoch, 1);

  // 2. Idempotent replay with same operationId
  const receipt2 = await saveRemoteSchedule({
    db: harness.db,
    admin: {},
    actor,
    command,
    now: new Date('2026-10-31T10:05:00.000Z'),
  });

  assert.equal(receipt2.status, 'already_recorded');
  assert.equal(receipt2.scheduleId, receipt1.scheduleId);
  assert.equal(receipt2.version, 1);

  // 3. Unauthorized actor fails
  await assert.rejects(async () => {
    await saveRemoteSchedule({
      db: harness.db,
      admin: {},
      actor: { uid: 'emp_123', active: true, companyId: 'zawolf', capabilities: [] },
      command: { ...command, operationId: 'op_unauth' },
      now: new Date('2026-10-31T10:10:00.000Z'),
    });
  }, (err) => err.code === 'not_authorized');

  await harness.close();
});

