const test = require('node:test');
const assert = require('node:assert/strict');
const {
  effective,
  assertWebAttendanceAccess,
  validateGrantInput,
} = require('../web-attendance-access');

test('web attendance anywhere requires an explicit grant flag', () => {
  assert.equal(validateGrantInput({ employeeId: 'u1', scope: 'permanent' }).allowAnyLocation, false);
  assert.equal(validateGrantInput({ employeeId: 'u1', scope: 'permanent', allowAnyLocation: true }).allowAnyLocation, true);
  assert.equal(validateGrantInput({ employeeId: 'u1', scope: 'permanent', allowAnyLocation: 'true' }).allowAnyLocation, false);
});

test('web attendance access: period boundaries are inclusive in Cairo date', () => {
  const grant = { status: 'active', scope: 'period', startDate: '2026-09-13', endDate: '2026-09-15' };
  assert.equal(effective(grant, '2026-09-13'), true);
  assert.equal(effective(grant, '2026-09-15'), true);
  assert.equal(effective(grant, '2026-09-16'), false);
  assert.equal(effective({ ...grant, status: 'revoked' }, '2026-09-14'), false);
  assert.equal(effective({ status: 'active', scope: 'permanent' }, '2026-09-14'), true);
});

test('web attendance access: gateway authorization rejects missing and expired grants', async () => {
  const grant = { status: 'active', scope: 'period', startDate: '2000-01-01', endDate: '2000-01-02' };
  const admin = { firestore: () => ({ collection: () => ({ doc: () => ({ get: async () => ({ exists: true, data: () => grant }) }) }) }) };
  await assert.rejects(
    assertWebAttendanceAccess({ admin, actor: { uid: 'employee-1' } }),
    (err) => err.code === 'web_attendance_not_authorized',
  );
});
