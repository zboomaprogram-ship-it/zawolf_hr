const test = require('node:test');
const assert = require('node:assert/strict');
const {
  reportKey,
  REPORT_RUN_LEASE_MS,
  reserveWorkspaceReport,
  completeWorkspaceReport,
  workspaceAuditTabTitle,
} = require('../workspace/reports');

function fakeDb() {
  const values = new Map();
  return {
    collection(name) {
      return { doc(id) {
        const key = `${name}/${id}`;
        return {
          async get() { const value = values.get(key); return { exists: value != null, data: () => value }; },
          async set(value, options) { values.set(key, options?.merge ? { ...values.get(key), ...value } : value); },
        };
      } };
    },
  };
}

test('daily, weekly, monthly and custom report keys are stable by scope and period', () => {
  for (const type of ['daily', 'weekly', 'monthly', 'custom']) {
    assert.equal(
      reportKey({ type, scopeId: 'hr', startDate: '2026-08-01', endDate: '2026-08-31' }),
      reportKey({ type, scopeId: 'hr', startDate: '2026-08-01', endDate: '2026-08-31' }),
    );
  }
});

test('a completed report is replayed and not generated again', async () => {
  const db = fakeDb();
  const key = reportKey({ type: 'workspace_audit', startDate: '2026-08-01', endDate: '2026-08-01' });
  const first = await reserveWorkspaceReport({ db, key, actorId: 'admin' });
  assert.equal(first.kind, 'new');
  await completeWorkspaceReport({ reservation: first, result: { resourceId: 'report-resource' } });
  const retry = await reserveWorkspaceReport({ db, key, actorId: 'admin' });
  assert.equal(retry.kind, 'replay');
  assert.deepEqual(retry.result, { resourceId: 'report-resource' });
});

test('a stale generating report is safely resumed instead of blocking its period forever', async () => {
  const db = fakeDb();
  const key = reportKey({ type: 'workspace_audit', startDate: '2026-08-01', endDate: '2026-08-30' });
  const startedAt = new Date('2026-08-30T09:00:00.000Z');
  const first = await reserveWorkspaceReport({ db, key, actorId: 'admin', now: startedAt });
  assert.equal(first.kind, 'new');

  const duringLease = await reserveWorkspaceReport({
    db, key, actorId: 'hr', now: new Date(startedAt.getTime() + REPORT_RUN_LEASE_MS - 1),
  });
  assert.equal(duringLease.kind, 'running');

  const resumed = await reserveWorkspaceReport({
    db, key, actorId: 'hr', now: new Date(startedAt.getTime() + REPORT_RUN_LEASE_MS + 1),
  });
  assert.equal(resumed.kind, 'new');
  assert.equal(resumed.resumed, true);
});

test('audit periods use independent tabs so completed reports are never overwritten', () => {
  assert.equal(
    workspaceAuditTabTitle({ startDate: '2026-08-01', endDate: '2026-08-30' }),
    'تدقيق_2026-08-01_2026-08-30',
  );
  assert.notEqual(
    workspaceAuditTabTitle({ startDate: '2026-08-01', endDate: '2026-08-30' }),
    workspaceAuditTabTitle({ startDate: '2026-08-31', endDate: '2026-08-31' }),
  );
});
