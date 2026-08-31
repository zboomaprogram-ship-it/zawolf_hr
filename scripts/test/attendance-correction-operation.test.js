const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isValidCorrectionSubmission,
  cairoDateKey,
  isSameCairoAttendanceDay,
} = require('../attendance-correction-operation');

test('correction submission needs a stable operation ID and valid request data', () => {
  assert.equal(isValidCorrectionSubmission({
    operationId: 'correction-123', attendanceId: 'attendance-123',
    reason: 'ازدحام الطريق', requestedCheckIn: new Date('2026-08-20T06:00:00Z'),
  }), true);
  assert.equal(isValidCorrectionSubmission({
    operationId: 'short', attendanceId: 'attendance-123',
    reason: 'سبب', requestedCheckIn: new Date('invalid'),
  }), false);
});

test('attendance correction respects the Cairo attendance day and cannot move later', () => {
  const original = new Date('2026-08-20T06:30:00Z');
  const earlierSameDay = new Date('2026-08-20T06:00:00Z');
  assert.equal(cairoDateKey(original), '2026-08-20');
  assert.equal(isSameCairoAttendanceDay(earlierSameDay, original), true);
  assert.equal(isSameCairoAttendanceDay(new Date('2026-08-20T07:00:00Z'), original), false);
});
