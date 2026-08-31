const test = require('node:test');
const assert = require('node:assert/strict');
const {
  activeReturnException,
  returnGraceDeadline,
} = require('../auto-attendance');

const workTimes = { start: 9 * 60, end: 17 * 60 };

test('company break defers automatic checkout until the break and return grace end', () => {
  const exception = activeReturnException({
    nowMinutes: 13 * 60 + 30,
    permissions: [],
    workTimes,
    policy: { autoCheckoutReturnGraceMinutes: 15 },
  });
  assert.deepEqual(exception, { start: 13 * 60, end: 14 * 60, reason: 'company_break' });
  const deadline = returnGraceDeadline({
    now: new Date('2026-08-25T11:30:00.000Z'),
    nowMinutes: 13 * 60 + 30,
    exception,
    policy: { autoCheckoutReturnGraceMinutes: 15 },
  });
  assert.equal(deadline.toISOString(), '2026-08-25T12:15:00.000Z');
});

test('approved mid-shift permission defers checkout until permission ends plus grace', () => {
  const exception = activeReturnException({
    nowMinutes: 10 * 60 + 20,
    permissions: [{ permissionType: 'mid_shift_exit', expectedTime: '10:00', durationMinutes: 90 }],
    workTimes,
    policy: { autoCheckoutReturnGraceMinutes: 20 },
  });
  assert.deepEqual(exception, { start: 10 * 60, end: 11 * 60 + 30, reason: 'approved_mid_shift_permission' });
  const deadline = returnGraceDeadline({
    now: new Date('2026-08-25T08:20:00.000Z'),
    nowMinutes: 10 * 60 + 20,
    exception,
    policy: { autoCheckoutReturnGraceMinutes: 20 },
  });
  assert.equal(deadline.toISOString(), '2026-08-25T09:50:00.000Z');
});

test('ordinary exit receives only the configured return grace', () => {
  const deadline = returnGraceDeadline({
    now: new Date('2026-08-25T08:00:00.000Z'),
    nowMinutes: 10 * 60,
    exception: null,
    policy: { autoCheckoutReturnGraceMinutes: 15 },
  });
  assert.equal(deadline.toISOString(), '2026-08-25T08:15:00.000Z');
});
