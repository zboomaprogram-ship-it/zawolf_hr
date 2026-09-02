'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  safePageSize,
  normalizePeriod,
  canInspectEmployee,
  normalizeTimelineRows,
} = require('../operational-visibility');
const {
  canManageOperationalVisibility,
} = require('../phase007-authorization');

test('only HR and admins can hide operational accounts', () => {
  assert.equal(canManageOperationalVisibility({ role: 'hr_admin' }), true);
  assert.equal(canManageOperationalVisibility({ role: 'super_admin' }), true);
  assert.equal(canManageOperationalVisibility({ role: 'manager' }), false);
});

test('timeline access is self, HR/admin, or explicit management relation', () => {
  const target = { uid: 'e1', managerIds: ['m1'] };
  assert.equal(canInspectEmployee({ uid: 'e1', role: 'employee' }, target), true);
  assert.equal(canInspectEmployee({ uid: 'm1', role: 'manager' }, target), true);
  assert.equal(canInspectEmployee({ uid: 'm2', role: 'manager' }, target), false);
  assert.equal(canInspectEmployee({ uid: 'hr1', role: 'hr_admin' }, target), true);
});

test('timeline is effective-date scoped, deduplicated, and paginated', () => {
  const period = normalizePeriod('2026-07-01', '2026-07-31T23:59:59Z');
  const page = normalizeTimelineRows([
    { id: 'a1', source: 'attendance', kind: 'attendance', data: { date: '2026-07-10', status: 'present' } },
    { id: 'a1', source: 'attendance', kind: 'attendance', data: { date: '2026-07-10', status: 'present' } },
    { id: 'p1', source: 'permissions', kind: 'permission', data: { requestDate: '2026-07-11', status: 'approved' } },
    { id: 'future', source: 'leaves', kind: 'leave', data: { startDate: '2026-08-01', status: 'approved' } },
  ], period, null, 1);
  assert.equal(page.items.length, 1);
  assert.equal(page.items[0].kind, 'permission');
  assert.equal(page.hasMore, true);
  assert.ok(page.nextCursor);
  assert.equal(safePageSize(1000), 100);
});

test('timeline recognizes legacy request and deduction date fields', () => {
  const period = normalizePeriod('2026-07-01', '2026-07-31T23:59:59Z');
  const page = normalizeTimelineRows([
    { id: 'd1', source: 'manual_deductions', kind: 'deduction', data: { dateKey: '2026-07-05', status: 'approved' } },
    { id: 'r1', source: 'employeeDeletionRequests', kind: 'account_deletion', data: { requestedAt: '2026-07-06T08:00:00Z', status: 'pending_hr' } },
    { id: 'c1', source: 'complaints', kind: 'complaint', data: { updatedAt: '2026-07-07T08:00:00Z', status: 'reviewed' } },
  ], period, null, 10);
  assert.deepEqual(page.items.map((item) => item.id), [
    'complaints:c1',
    'employeeDeletionRequests:r1',
    'manual_deductions:d1',
  ]);
});

test('timeline returns period totals without exposing internal deduction codes', () => {
  const period = normalizePeriod('2026-07-01', '2026-07-31T23:59:59Z');
  const page = normalizeTimelineRows([
    { id: 'a1', source: 'attendance', kind: 'attendance', data: { date: '2026-07-01', status: 'late_quarter_day' } },
    { id: 'a2', source: 'attendance', kind: 'attendance', data: { date: '2026-07-02', status: 'late_half_day' } },
    { id: 'l1', source: 'leaves', kind: 'leave', data: { date: '2026-07-03', status: 'approved' } },
    { id: 'p1', source: 'permissions', kind: 'permission', data: { date: '2026-07-04', status: 'approved' } },
    { id: 'r1', source: 'administrativeRequests', kind: 'request', data: { date: '2026-07-05', status: 'pending_hr' } },
    { id: 'd1', source: 'manual_deductions', kind: 'deduction', data: { date: '2026-07-06', dayFraction: 1 } },
  ], period, null, 1);
  assert.deepEqual(page.summary, {
    salaryDeductionDays: 1.75,
    leaveRequests: 1,
    permissionRequests: 1,
    otherRequests: 1,
  });
});

test('timeline rejects invalid or overlong periods', () => {
  assert.equal(normalizePeriod('bad', '2026-07-01'), null);
  assert.equal(normalizePeriod('2025-01-01', '2026-08-01'), null);
});
