'use strict';

const crypto = require('node:crypto');

// A report request can be interrupted after it has obtained its idempotency
// reservation (for example while Google Sheets is being contacted).  Keep the
// reservation for normal concurrent callers, but never let a crashed runtime
// block the same reporting period indefinitely.
const REPORT_RUN_LEASE_MS = 5 * 60 * 1000;

function reportKey({ type, scopeId = 'company', startDate, endDate }) {
  const validType = String(type || '').trim();
  const validScope = String(scopeId || '').trim();
  const start = String(startDate || '').slice(0, 10);
  const end = String(endDate || '').slice(0, 10);
  if (!/^[a-z0-9_-]{2,64}$/i.test(validType) || !validScope ||
      !/^\d{4}-\d{2}-\d{2}$/.test(start) || !/^\d{4}-\d{2}-\d{2}$/.test(end)) {
    const error = new Error('بيانات فترة التقرير غير صحيحة.');
    error.code = 'validation';
    throw error;
  }
  return `${validType}:${validScope}:${start}:${end}`;
}

function reportRunId(key) {
  return `report_${crypto.createHash('sha256').update(key).digest('hex').slice(0, 40)}`;
}

function workspaceAuditTabTitle({ startDate, endDate }) {
  const start = String(startDate || '').slice(0, 10);
  const end = String(endDate || '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start) || !/^\d{4}-\d{2}-\d{2}$/.test(end) || start > end) {
    const error = new Error('بيانات فترة التقرير غير صحيحة.');
    error.code = 'validation';
    throw error;
  }
  // Every period needs a distinct tab. Reusing a static audit tab would make a
  // newer period overwrite a report that is already part of the audit record.
  return `تدقيق_${start}_${end}`;
}

function toMillis(value) {
  if (value instanceof Date) return value.getTime();
  if (typeof value?.toDate === 'function') return value.toDate().getTime();
  const parsed = new Date(value).getTime();
  return Number.isNaN(parsed) ? 0 : parsed;
}

async function reserveWorkspaceReport({ db, key, actorId, now = new Date(), leaseMs = REPORT_RUN_LEASE_MS }) {
  const ref = db.collection('workspaceReportRuns').doc(reportRunId(key));
  const existing = await ref.get();
  if (existing.exists) {
    const data = existing.data() || {};
    if (data.state === 'ready' && data.result) return { kind: 'replay', ref, result: data.result };
    if (data.state === 'generating') {
      const startedAt = toMillis(data.startedAt || data.updatedAt);
      if (startedAt && now.getTime() - startedAt < leaseMs) return { kind: 'running', ref };
      await ref.set({
        key,
        actorId,
        state: 'generating',
        startedAt: now,
        updatedAt: now,
        resumedCount: Number(data.resumedCount || 0) + 1,
      }, { merge: true });
      return { kind: 'new', ref, resumed: true };
    }
  }
  await ref.set({ key, actorId, state: 'generating', startedAt: now, updatedAt: now }, { merge: true });
  return { kind: 'new', ref };
}

async function completeWorkspaceReport({ reservation, result, now = new Date() }) {
  await reservation.ref.set({ state: 'ready', result, completedAt: now, updatedAt: now }, { merge: true });
  return result;
}

async function failWorkspaceReport({ reservation, now = new Date() }) {
  if (!reservation?.ref) return;
  await reservation.ref.set({ state: 'failed_retryable', updatedAt: now }, { merge: true });
}

module.exports = {
  REPORT_RUN_LEASE_MS,
  reportKey,
  reportRunId,
  workspaceAuditTabTitle,
  reserveWorkspaceReport,
  completeWorkspaceReport,
  failWorkspaceReport,
};
