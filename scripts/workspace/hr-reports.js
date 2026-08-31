'use strict';

// HR reports intentionally use the business-effective date of each record.
// Approval/submission timestamps are descriptive only: they must never move a
// late-approved permission or deduction into a different payroll/report period.

function dateKey(value) {
  if (typeof value === 'string') return value.slice(0, 10);
  if (value && typeof value.toDate === 'function') return dateKey(value.toDate());
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  return '';
}

function inPeriod(value, { startDate, endDate }) {
  const key = dateKey(value);
  return Boolean(key) && key >= startDate && key <= endDate;
}

function userLabel(record, usersById) {
  const user = usersById.get(String(record.userId || '')) || {};
  return [
    String(user.employeeId || record.employeeId || ''),
    String(user.displayName || user.name || record.employeeName || ''),
    String(user.department || record.department || ''),
  ];
}

function buildHrOperationalRows({
  reportType,
  period,
  attendance = [],
  permissions = [],
  leaves = [],
  users = [],
}) {
  const usersById = new Map(users.map((user) => [String(user.id || user.userId || ''), user]));
  if (reportType === 'attendance') {
    return {
      headers: ['تاريخ الحضور', 'كود الموظف', 'الموظف', 'القسم', 'الحالة', 'وقت الحضور', 'التأخير بالدقائق', 'حالة الخصم'],
      rows: attendance
        .filter((item) => inPeriod(item.date, period))
        .map((item) => [
          dateKey(item.date), ...userLabel(item, usersById), String(item.status || ''),
          String(item.checkInTime || item.checkInAt || ''), String(item.lateMinutes ?? ''),
          String(item.salaryDeductionApprovalStatus || ''),
        ]),
    };
  }
  if (reportType === 'requests') {
    const permissionRows = permissions
      .filter((item) => inPeriod(item.requestDate, period))
      .map((item) => [
        dateKey(item.requestDate), ...userLabel(item, usersById), 'إذن',
        String(item.permissionType || ''), String(item.status || ''),
        String(item.reason || ''),
      ]);
    const leaveRows = leaves
      .filter((item) => {
        const start = dateKey(item.startDate);
        const end = dateKey(item.endDate);
        return Boolean(start && end) && start <= period.endDate && end >= period.startDate;
      })
      .map((item) => [
        `${dateKey(item.startDate)} إلى ${dateKey(item.endDate)}`,
        ...userLabel(item, usersById), 'إجازة', String(item.leaveType || ''),
        String(item.status || ''), String(item.reason || ''),
      ]);
    return {
      headers: ['تاريخ التنفيذ', 'كود الموظف', 'الموظف', 'القسم', 'نوع الطلب', 'التصنيف', 'الحالة', 'السبب'],
      rows: [...permissionRows, ...leaveRows],
    };
  }
  if (reportType === 'deductions') {
    return {
      headers: ['تاريخ الاستحقاق', 'كود الموظف', 'الموظف', 'القسم', 'سبب الخصم', 'القيمة', 'النسبة', 'حالة اعتماد الخصم'],
      rows: attendance
        .filter((item) => inPeriod(item.date, period))
        .filter((item) => Number(item.salaryDeductionAmount || 0) > 0 ||
          Number(item.salaryDeductionFraction || 0) > 0 ||
          String(item.salaryDeductionApprovalStatus || '') === 'pending_hr')
        .map((item) => [
          dateKey(item.date), ...userLabel(item, usersById), String(item.salaryDeductionReason || item.deductionReason || item.status || ''),
          String(item.salaryDeductionAmount ?? ''), String(item.salaryDeductionFraction ?? ''),
          String(item.salaryDeductionApprovalStatus || ''),
        ]),
    };
  }
  const error = new Error('نوع تقرير الموارد البشرية غير مدعوم.');
  error.code = 'validation';
  throw error;
}

module.exports = { dateKey, inPeriod, buildHrOperationalRows };
