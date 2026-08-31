const test = require('node:test');
const assert = require('node:assert/strict');
const {
  planWorkspaceSourceImport,
  nextSourceImportRun,
  SOURCE_IMPORT_LEASE_MS,
} = require('../workspace/source-import');

test('source import preserves folder hierarchy with stable resource IDs', () => {
  let generated = 0;
  const plan = planWorkspaceSourceImport([
    { id: 'department', parentExternalId: 'company-root' },
    { id: 'employee', parentExternalId: 'department' },
    { id: 'sheet', parentExternalId: 'employee' },
  ], new Map([['department', 'resource-department']]), () => `new-${++generated}`);

  assert.deepEqual(plan.map((item) => ({
    id: item.resourceId,
    parent: item.parentResourceId,
    existed: item.existed,
  })), [
    { id: 'resource-department', parent: null, existed: true },
    { id: 'new-1', parent: 'resource-department', existed: false },
    { id: 'new-2', parent: 'new-1', existed: false },
  ]);
});

test('source import does not create a self-parenting resource', () => {
  const plan = planWorkspaceSourceImport(
    [{ id: 'same', parentExternalId: 'same' }],
    new Map([['same', 'resource-same']]),
    () => 'unused',
  );
  assert.equal(plan[0].parentResourceId, null);
});

test('source import leases one active run and resumes stale reconciliation safely', () => {
  const now = 1000;
  assert.deepEqual(
    nextSourceImportRun({ state: 'running', leaseUntilMs: now + 1 }, {
      token: 'next', nowMs: now,
    }),
    { kind: 'busy' },
  );
  const resumed = nextSourceImportRun(
    { state: 'failed_retryable', resumedCount: 2, leaseUntilMs: now - 1 },
    { token: 'resume-token', nowMs: now },
  );
  assert.equal(resumed.kind, 'resume');
  assert.equal(resumed.value.resumedCount, 3);
  assert.equal(resumed.value.leaseUntilMs, now + SOURCE_IMPORT_LEASE_MS);
});
