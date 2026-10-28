'use strict';

const DAY_MS = 24 * 60 * 60 * 1000;

function isoDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function isoWeekday(dateKey) {
  if (!isoDate(dateKey)) throw new Error('invalid_date');
  return new Date(`${dateKey}T00:00:00.000Z`).getUTCDay() || 7;
}

function weekStartDate(dateKey, startDay) {
  if (!isoDate(dateKey) || !Number.isInteger(startDay) || startDay < 1 || startDay > 7) {
    throw new Error('invalid_week');
  }
  const date = new Date(`${dateKey}T00:00:00.000Z`);
  const offset = (isoWeekday(dateKey) - startDay + 7) % 7;
  return new Date(date.getTime() - offset * DAY_MS).toISOString().slice(0, 10);
}

function weekEndDate(dateKey, startDay) {
  return new Date(new Date(`${weekStartDate(dateKey, startDay)}T00:00:00.000Z`).getTime() + 6 * DAY_MS)
    .toISOString().slice(0, 10);
}

function evaluateRemoteEligibility({
  employee,
  companyId,
  policy,
  date,
  schedules = [],
  datedAuthorizations = [],
  leaves = [],
  holidays = [],
  restDates = [],
}) {
  if (!isoDate(date)) return denied('invalid_date');
  if (!employee || employee.isActive !== true) return denied('account_inactive');
  if (companyId && employee.companyId !== companyId) return denied('wrong_company');
  if (employee.suspended === true || employee.employmentStatus === 'suspended') return denied('employment_suspended');
  if (!policy || policy.enabled !== true) return denied('remote_work_disabled');
  const eligibility = policy.eligibility || {};
  if (!Number.isInteger(eligibility.weekStartDay) || eligibility.weekStartDay < 1 || eligibility.weekStartDay > 7 ||
      !Number.isInteger(eligibility.daysPerWeek) || eligibility.daysPerWeek < 1 ||
      !Array.isArray(eligibility.allowedWeekdays) || eligibility.allowedWeekdays.length === 0 ||
      eligibility.daysPerWeek > eligibility.allowedWeekdays.length ||
      eligibility.allowedWeekdays.some((day) => !Number.isInteger(day) || day < 1 || day > 7) ||
      new Set(eligibility.allowedWeekdays).size !== eligibility.allowedWeekdays.length) {
    return denied('policy_configuration_invalid');
  }
  if (employee.isProbation === true && eligibility.probationEligible !== true) return denied('probation_ineligible');
  if (!Array.isArray(eligibility.allowedWeekdays) || !eligibility.allowedWeekdays.includes(isoWeekday(date))) {
    return denied('weekday_not_allowed');
  }
  if (holidays.some((entry) => covers(entry, date))) return denied('company_holiday');
  if (restDates.includes(date)) return denied('employee_rest_day');
  if (leaves.some((entry) => entry.status === 'approved' && covers(entry, date) && !isRemoteAlias(entry.leaveType))) {
    return denied('approved_leave');
  }

  const weekStart = weekStartDate(date, eligibility.weekStartDay);
  const weekEnd = weekEndDate(date, eligibility.weekStartDay);
  const matchingSchedules = schedules.filter((entry) => entry.status === 'approved' && covers(entry, date));
  if (matchingSchedules.length > 1) return denied('schedule_overlap');
  const approved = [...schedules, ...datedAuthorizations]
    .filter((entry) => entry.status === 'approved' && overlaps(entry, weekStart, weekEnd));
  const usedDates = new Set(approved
    .flatMap((entry) => datesInWeek(entry, weekStart))
    .filter((value) => isoDate(value) && value >= weekStart && value <= weekEnd));
  for (const entry of approved) {
    if (isoDate(entry.date) && isoDate(entry.replacesDate) && entry.date !== entry.replacesDate &&
        entry.date >= weekStart && entry.date <= weekEnd &&
        entry.replacesDate >= weekStart && entry.replacesDate <= weekEnd) {
      usedDates.delete(entry.replacesDate);
    }
  }
  const authorization = usedDates.has(date) ? approved
    .filter((entry) => covers(entry, date))
    .sort((left, right) => Number(right.version || 0) - Number(left.version || 0))[0] : null;
  const allowance = Number(eligibility.daysPerWeek || 0);
  if (usedDates.size > allowance || (!authorization && usedDates.size >= allowance)) {
    return denied('weekly_allowance_conflict', { weekStart, weekEnd, usedDates: [...usedDates].sort() });
  }
  if (!authorization) return denied('authorization_required', { weekStart, weekEnd, usedDates: [...usedDates].sort() });
  return {
    eligible: true,
    reason: authorization ? 'approved_authorization' : 'eligible',
    date,
    weekStart,
    weekEnd,
    authorizationId: authorization?.id || null,
    usedDates: [...usedDates].sort(),
  };
}

function covers(entry, date) {
  if (Array.isArray(entry.dates)) return entry.dates.includes(date);
  if (entry.date) return entry.date === date;
  return isoDate(entry.startDate) && isoDate(entry.endDate) && entry.startDate <= date && date <= entry.endDate &&
    (!Array.isArray(entry.weekdays) || entry.weekdays.includes(isoWeekday(date)));
}

function datesInWeek(entry, weekStart) {
  if (Array.isArray(entry.dates)) return entry.dates;
  if (entry.date) return [entry.date];
  const start = new Date(`${weekStart}T00:00:00.000Z`).getTime();
  return Array.from({ length: 7 }, (_, index) => new Date(start + index * DAY_MS).toISOString().slice(0, 10))
    .filter((day) => covers(entry, day));
}

function overlaps(entry, start, end) {
  if (Array.isArray(entry.dates)) return entry.dates.some((date) => date >= start && date <= end);
  if (entry.date) return entry.date >= start && entry.date <= end;
  return typeof entry.startDate === 'string' && typeof entry.endDate === 'string' && entry.startDate <= end && entry.endDate >= start;
}

function denied(reason, details = {}) {
  return { eligible: false, reason, ...details };
}

const REMOTE_ALIASES = new Set(['remote', 'wfh', 'work_from_home', 'عمل عن بعد', 'يوم عمل عن بعد']);
function isRemoteAlias(value) { return REMOTE_ALIASES.has(String(value || '').trim().toLowerCase()); }

module.exports = { evaluateRemoteEligibility, isoDate, isoWeekday, weekStartDate, weekEndDate, isRemoteAlias };
