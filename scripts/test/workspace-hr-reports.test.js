'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildHrOperationalRows } = require('../workspace/hr-reports');

const period = { startDate: '2026-07-26', endDate: '2026-08-25' };
const users = [{ id: 'u1', employeeId: 'BD-1200', displayName: 'ميرا', department: 'BD' }];

test('permission reports use execution date, not a later approval date', () => {
  const report = buildHrOperationalRows({
    reportType: 'requests', period, users,
    permissions: [{ userId: 'u1', requestDate: '2026-07-22', approvedAt: '2026-08-02', status: 'approved' }, {
      userId: 'u1', requestDate: '2026-08-02', approvedAt: '2026-08-03', status: 'approved', permissionType: 'late_arrival', reason: 'حالة من السفر',
    }],
  });
  assert.equal(report.rows.length, 1);
  assert.equal(report.rows[0][0], '2026-08-02');
  assert.equal(report.rows[0][4], 'إذن');
});

test('attendance deductions use attendance effective date and leave overlaps its actual dates', () => {
  const deductions = buildHrOperationalRows({
    reportType: 'deductions', period, users,
    attendance: [
      { userId: 'u1', date: '2026-07-22', salaryDeductionAmount: 100, salaryDeductionApprovalStatus: 'approved' },
      { userId: 'u1', date: '2026-08-03', salaryDeductionAmount: 50, salaryDeductionApprovalStatus: 'approved', salaryDeductionReason: 'تأخير' },
    ],
  });
  assert.equal(deductions.rows.length, 1);
  assert.equal(deductions.rows[0][0], '2026-08-03');

  const requests = buildHrOperationalRows({
    reportType: 'requests', period, users,
    leaves: [{ userId: 'u1', startDate: '2026-08-24', endDate: '2026-08-27', status: 'approved', leaveType: 'annual' }],
  });
  assert.equal(requests.rows.length, 1);
  assert.match(requests.rows[0][0], /2026-08-24/);
});

test('unsupported report types are rejected safely', () => {
  assert.throws(
    () => buildHrOperationalRows({ reportType: 'payroll', period }),
    /غير مدعوم/,
  );
});
