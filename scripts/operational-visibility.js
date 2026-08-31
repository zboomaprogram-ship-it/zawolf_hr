'use strict';

const USER_ID = /^[A-Za-z0-9_-]{1,128}$/;
const MAX_PAGE_SIZE = 100;

function safeUserId(value) {
  const id = String(value || '').trim();
  return USER_ID.test(id) ? id : null;
}

function safePageSize(value, fallback = 50) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(MAX_PAGE_SIZE, parsed));
}

function normalizePeriod(fromValue, toValue) {
  const from = new Date(String(fromValue || ''));
  const to = new Date(String(toValue || ''));
  const maxSpanMs = 366 * 24 * 60 * 60 * 1000;
  if (!Number.isFinite(from.getTime()) || !Number.isFinite(to.getTime()) ||
      to < from || to.getTime() - from.getTime() > maxSpanMs) return null;
  return { from, to };
}

function canInspectEmployee(actor, target) {
  if (!actor?.uid || !target) return false;
  if (actor.uid === target.uid) return true;
  if (['hr_admin', 'hr_manager', 'super_admin'].includes(actor.role)) return true;
  if (!['manager', 'team_leader'].includes(actor.role)) return false;
  return target.managerId === actor.uid || target.teamLeaderId === actor.uid ||
    (Array.isArray(target.managerIds) && target.managerIds.includes(actor.uid));
}

function valueAsDate(value) {
  if (value?.toDate) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}/.test(value)) {
    const parsed = new Date(value.length === 10 ? `${value}T12:00:00Z` : value);
    return Number.isFinite(parsed.getTime()) ? parsed : null;
  }
  return null;
}

const DATE_KEYS = [
  'businessEffectiveAt', 'effectiveAt', 'attendanceDate', 'date', 'startDate',
  'requestDate', 'requestDateTimestamp', 'resignationDate', 'dateKey',
  'requestedAt', 'submittedAt', 'createdAt', 'updatedAt', 'timestamp',
];

function effectiveDate(data) {
  for (const key of DATE_KEYS) {
    const date = valueAsDate(data?.[key]);
    if (date) return date;
  }
  return null;
}

function normalizeTimelineRows(sourceRows, period, cursor, pageSize) {
  const seen = new Set();
  const rows = [];
  for (const sourceRow of sourceRows) {
    const source = String(sourceRow.source || 'unknown');
    const id = String(sourceRow.id || '');
    const key = `${source}:${id}`;
    const date = effectiveDate(sourceRow.data);
    if (!id || !date || date < period.from || date > period.to || seen.has(key)) {
      continue;
    }
    seen.add(key);
    rows.push({
      id: key,
      source,
      kind: String(sourceRow.kind || 'unknown'),
      effectiveAt: date.toISOString(),
      status: String(sourceRow.data?.status || sourceRow.data?.salaryDeductionApprovalStatus || 'unknown'),
      summaryAr: String(sourceRow.data?.reason || sourceRow.data?.salaryDeductionLabel || ''),
    });
  }
  rows.sort((a, b) => b.effectiveAt.localeCompare(a.effectiveAt) || a.id.localeCompare(b.id));
  const afterCursor = cursor
    ? rows.filter((row) => `${row.effectiveAt}|${row.id}` < cursor)
    : rows;
  const items = afterCursor.slice(0, pageSize);
  const last = items.at(-1);
  return {
    items,
    hasMore: afterCursor.length > items.length,
    nextCursor: last ? `${last.effectiveAt}|${last.id}` : null,
  };
}

module.exports = {
  safeUserId,
  safePageSize,
  normalizePeriod,
  canInspectEmployee,
  effectiveDate,
  normalizeTimelineRows,
};
