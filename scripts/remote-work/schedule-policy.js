'use strict';

const { isoDate, isoWeekday, weekStartDate } = require('./eligibility');
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const TIME = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
const DAY_MS = 24 * 60 * 60 * 1000;
const timeMinutes = (value) => Number(value.slice(0, 2)) * 60 + Number(value.slice(3));
const issue = (errors, path, code) => errors.push({ path, code });
const validEligibility = (value) => value && Number.isInteger(value.daysPerWeek) && value.daysPerWeek >= 1 &&
  Array.isArray(value.allowedWeekdays) && value.allowedWeekdays.length > 0 &&
  value.allowedWeekdays.every((day) => Number.isInteger(day) && day >= 1 && day <= 7) &&
  new Set(value.allowedWeekdays).size === value.allowedWeekdays.length &&
  value.daysPerWeek <= value.allowedWeekdays.length &&
  Number.isInteger(value.weekStartDay) && value.weekStartDay >= 1 && value.weekStartDay <= 7;

// Pure contracts used before a server command commits a schedule. They do not
// grant authority, write records, or choose an approval route.
function validateScheduleRevision({ schedule, policy, today, existingSchedules = [] }) {
  const errors = [];
  if (!schedule || typeof schedule !== 'object' || Array.isArray(schedule)) return { valid: false, errors: [{ path: 'schedule', code: 'required' }] };
  const eligibility = policy?.eligibility;
  if (!validEligibility(eligibility)) {
    issue(errors, 'policy.eligibility', 'invalid_policy');
  }
  if (!SAFE_ID.test(String(schedule.employeeId || ''))) issue(errors, 'employeeId', 'invalid_id');
  if (!isoDate(today)) issue(errors, 'today', 'invalid_date');
  if (!isoDate(schedule.startDate)) issue(errors, 'startDate', 'invalid_date');
  if (!isoDate(schedule.endDate)) issue(errors, 'endDate', 'invalid_date');
  if (isoDate(schedule.startDate) && isoDate(schedule.endDate)) {
    if (schedule.endDate < schedule.startDate) issue(errors, 'endDate', 'invalid_range');
    if (isoDate(today) && schedule.startDate < today) issue(errors, 'startDate', 'past_date');
    if (!Array.isArray(existingSchedules) || existingSchedules.length > 100) issue(errors, 'existingSchedules', 'invalid_type');
    else if (existingSchedules.some((old) => old?.status === 'approved' && old.employeeId === schedule.employeeId &&
      isoDate(old.startDate) && isoDate(old.endDate) &&
      old.startDate <= schedule.endDate && old.endDate >= schedule.startDate)) issue(errors, 'startDate', 'schedule_overlap');
  }
  const days = schedule.weekdays;
  if (!Array.isArray(days) || !days.length || days.some((day) => !Number.isInteger(day) || day < 1 || day > 7) || new Set(days).size !== days.length) {
    issue(errors, 'weekdays', 'invalid_weekdays');
  } else if (validEligibility(eligibility) && (days.some((day) => !eligibility.allowedWeekdays.includes(day)) || days.length > eligibility.daysPerWeek)) {
    issue(errors, 'weekdays', 'weekly_allowance_conflict');
  }
  const shift = policy?.schedule || {};
  if (!TIME.test(shift.startTime || '') || !TIME.test(shift.endTime || '') || !TIME.test(shift.checkInOpenTime || '') ||
      !Number.isInteger(shift.endDayOffset) || shift.endDayOffset < 0 || shift.endDayOffset > 1) {
    issue(errors, 'policy.schedule', 'invalid_shift');
  } else if (timeMinutes(shift.checkInOpenTime) > timeMinutes(shift.startTime) ||
      timeMinutes(shift.endTime) + shift.endDayOffset * 1440 <= timeMinutes(shift.startTime)) {
    issue(errors, 'policy.schedule', 'invalid_shift_order');
  }
  return { valid: errors.length === 0, errors };
}

function resolveWeeklyExceptionDates({ weekStart, schedule, policy, exceptions = [], carryoverDays = 0 }) {
  const eligibility = policy?.eligibility || {};
  if (!isoDate(weekStart) || !Number.isInteger(eligibility.weekStartDay) || eligibility.weekStartDay < 1 ||
      eligibility.weekStartDay > 7 || weekStartDate(weekStart, eligibility.weekStartDay) !== weekStart) return { error: 'invalid_week' };
  if (!validEligibility(eligibility) || !schedule || !isoDate(schedule.startDate) || !isoDate(schedule.endDate) || schedule.endDate < schedule.startDate ||
      !Array.isArray(schedule.weekdays) || !schedule.weekdays.length || !Array.isArray(eligibility.allowedWeekdays) ||
      schedule.weekdays.some((day) => !Number.isInteger(day) || !eligibility.allowedWeekdays.includes(day)) ||
      new Set(schedule.weekdays).size !== schedule.weekdays.length ||
      !Number.isInteger(eligibility.daysPerWeek) || eligibility.daysPerWeek < 1 || !Array.isArray(exceptions) || exceptions.length > 100) {
    return { error: 'policy_configuration_invalid' };
  }
  if (!Number.isInteger(carryoverDays) || carryoverDays < 0 ||
      (carryoverDays > 0 && (eligibility.carryoverEnabled !== true || !Number.isInteger(eligibility.carryoverCap) || carryoverDays > eligibility.carryoverCap))) {
    return { error: 'carryover_invalid' };
  }
  const start = new Date(`${weekStart}T00:00:00.000Z`).getTime();
  const week = Array.from({ length: 7 }, (_, index) => new Date(start + index * DAY_MS).toISOString().slice(0, 10));
  const original = new Set(week.filter((date) => date >= schedule.startDate && date <= schedule.endDate && schedule.weekdays.includes(isoWeekday(date))));
  const dates = new Set(original);
  const ids = new Set();
  const replaced = new Set();
  const targets = new Set();
  const approved = [];
  for (const item of exceptions) {
    if (!item || !SAFE_ID.test(String(item.id || '')) || ids.has(item.id) || !['pending', 'approved', 'rejected'].includes(item.status)) return { error: 'invalid_exception' };
    ids.add(item.id);
    if (item.status !== 'approved') continue;
    if (!isoDate(item.date) || !week.includes(item.date) || item.date < schedule.startDate || item.date > schedule.endDate ||
        !eligibility.allowedWeekdays.includes(isoWeekday(item.date)) || !['replacement', 'addition'].includes(item.kind) ||
        !Array.isArray(item.approvalSnapshot) || !item.approvalSnapshot.length ||
        !item.approvalSnapshot.every((entry) => SAFE_ID.test(String(entry?.actorId || '')) && entry.decision === 'approved') ||
        targets.has(item.date)) return { error: 'invalid_exception' };
    if (item.kind === 'replacement') {
      if (!original.has(item.replacesDate) || item.date === item.replacesDate || replaced.has(item.replacesDate)) return { error: 'invalid_replacement' };
      replaced.add(item.replacesDate);
    } else if (item.replacesDate != null) return { error: 'invalid_exception' };
    targets.add(item.date);
    approved.push(item);
  }
  for (const date of replaced) dates.delete(date);
  for (const item of approved) {
    if (dates.has(item.date)) return { error: 'exception_date_conflict' };
    dates.add(item.date);
  }
  if (dates.size > eligibility.daysPerWeek + carryoverDays) return { error: 'weekly_allowance_conflict' };
  return { weekStart, dates: [...dates].sort(), appliedExceptions: structuredClone(approved) };
}

module.exports = { validateScheduleRevision, resolveWeeklyExceptionDates };
