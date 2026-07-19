const test = require('node:test');
const assert = require('node:assert/strict');
const { cycleForKey, keyForDateParts } = require('../payroll-cycle');

test('cycle stays in current month through day 25', () => {
  assert.equal(keyForDateParts(2026, 7, 25), '2026-07');
  assert.deepEqual(cycleForKey('2026-07'), {
    key: '2026-07',
    startDate: '2026-06-26',
    endDate: '2026-07-25',
    nextStartDate: '2026-07-26',
  });
});

test('cycle advances on day 26 and handles December', () => {
  assert.equal(keyForDateParts(2026, 7, 26), '2026-08');
  assert.equal(keyForDateParts(2026, 12, 26), '2027-01');
  assert.deepEqual(cycleForKey('2027-01'), {
    key: '2027-01',
    startDate: '2026-12-26',
    endDate: '2027-01-25',
    nextStartDate: '2027-01-26',
  });
});
