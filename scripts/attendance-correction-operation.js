const OPERATION_ID_PATTERN = /^[A-Za-z0-9_-]{8,180}$/;
const ATTENDANCE_ID_PATTERN = /^[A-Za-z0-9_-]{3,180}$/;

function isValidCorrectionSubmission({ operationId, attendanceId, reason, requestedCheckIn }) {
  return OPERATION_ID_PATTERN.test(String(operationId || '')) &&
    ATTENDANCE_ID_PATTERN.test(String(attendanceId || '')) &&
    String(reason || '').trim().length >= 5 &&
    requestedCheckIn instanceof Date && !Number.isNaN(requestedCheckIn.getTime());
}

function cairoDateKey(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const field = (type) => parts.find((part) => part.type === type)?.value || '';
  return `${field('year')}-${field('month')}-${field('day')}`;
}

function isSameCairoAttendanceDay(requestedCheckIn, originalCheckIn) {
  return cairoDateKey(requestedCheckIn) !== '' &&
    cairoDateKey(requestedCheckIn) === cairoDateKey(originalCheckIn) &&
    requestedCheckIn.getTime() <= originalCheckIn.getTime();
}

module.exports = {
  isValidCorrectionSubmission,
  cairoDateKey,
  isSameCairoAttendanceDay,
};
