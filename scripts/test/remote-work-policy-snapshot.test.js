'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryBackend } = require('./helpers/remote-work-fixtures');
const { hashPolicyAggregate } = require('../remote-work/policy-publication');
const { loadCompanyRemotePolicySnapshot } = require('../remote-work/policy-snapshot');
const before = new Date('2026-11-30T23:59:59.999Z');
const effective = new Date('2026-12-01T00:00:00.000Z');
function setup() {
  const db = createMemoryBackend();
  const base = (start) => ({ attendancePolicy: { defaultStartTime: start, remoteWorkPolicy: { schemaVersion: 1, enabled: false } },
    remoteWorkPolicy: { schemaVersion: 1, enabled: false } });
  for (const [revision, time, start] of [[1, '2026-11-01T00:00:00.000Z', '08:00'], [2, effective.toISOString(), '09:30']]) {
    const aggregate = base(start);
    db.seed('attendancePolicyRevisions', `zawolf_${revision}`, { companyId: 'zawolf', revision, revisionId: String(revision),
      state: revision === 1 ? 'published' : 'scheduled', effectiveFrom: time, aggregate, payloadHash: hashPolicyAggregate(aggregate) });
  }
  db.seed('attendancePolicyHeads', 'zawolf', { companyId: 'zawolf', revision: 2, activeRevision: 1, version: 2,
    eligibilityEpoch: 4, scheduledRevisions: [{ revision: 2, revisionId: '2', effectiveFrom: effective.toISOString() }] });
  db.seed('companies', 'zawolf', { attendancePolicyRevision: 1, attendancePolicy: base('08:00').attendancePolicy });
  return db;
}

test('server snapshot changes at the exact effective instant without mutating the projection', async () => {
  const f = setup();
  const input = { db: f.db, companyId: 'zawolf' };
  const old = await loadCompanyRemotePolicySnapshot({ ...input, now: before });
  const current = await loadCompanyRemotePolicySnapshot({ ...input, now: effective });
  assert.equal(old.revision, 1);
  assert.equal(old.aggregate.attendancePolicy.defaultStartTime, '08:00');
  assert.equal(current.revision, 2);
  assert.equal(current.aggregate.attendancePolicy.defaultStartTime, '09:30');
  assert.equal(current.headVersion, 2);
  assert.equal(current.eligibilityEpoch, 4);
  assert.deepEqual(current.sourceRevisionIds, ['zawolf_2']);
  assert.match(current.hash, /^[0-9a-f]{64}$/);
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '08:00');
  assert.equal(f.writes.length, 0);
});

test('snapshot selects the most recent effective instant rather than largest revision', async () => {
  const f = setup();
  const later = f.read('attendancePolicyRevisions', 'zawolf_1');
  f.seed('attendancePolicyRevisions', 'zawolf_1', { ...later, effectiveFrom: '2026-12-02T00:00:00.000Z' });
  f.seed('attendancePolicyHeads', 'zawolf', { companyId: 'zawolf', activeRevision: 0, revision: 2, version: 2,
    scheduledRevisions: [{ revision: 1, revisionId: '1', effectiveFrom: '2026-12-02T00:00:00.000Z' },
      { revision: 2, revisionId: '2', effectiveFrom: effective.toISOString() }] });
  const result = await loadCompanyRemotePolicySnapshot({ db: f.db, companyId: 'zawolf', now: new Date('2026-12-03T00:00:00Z') });
  assert.equal(result.revision, 1);
  assert.equal(result.aggregate.attendancePolicy.defaultStartTime, '08:00');
});

test('missing active policy is an explicit error instead of falling back to legacy settings', async () => {
  const f = setup();
  f.seed('attendancePolicyHeads', 'zawolf', { companyId: 'zawolf', activeRevision: 0, revision: 2, version: 2,
    scheduledRevisions: [{ revision: 2, revisionId: '2', effectiveFrom: effective.toISOString() }] });
  await assert.rejects(loadCompanyRemotePolicySnapshot({ db: f.db, companyId: 'zawolf', now: before }), (error) => error.code === 'remote_policy_missing');
});

for (const corruption of ['missing', 'company', 'effective_time', 'hash']) {
  test(`snapshot rejects ${corruption} published revision without returning stale policy`, async () => {
    const f = setup();
    const revision = f.read('attendancePolicyRevisions', 'zawolf_2');
    if (corruption === 'missing') f.documents.delete('attendancePolicyRevisions/zawolf_2');
    if (corruption === 'company') f.seed('attendancePolicyRevisions', 'zawolf_2', { ...revision, companyId: 'other' });
    if (corruption === 'effective_time') f.seed('attendancePolicyRevisions', 'zawolf_2', { ...revision, effectiveFrom: '2026-12-02T00:00:00.000Z' });
    if (corruption === 'hash') f.seed('attendancePolicyRevisions', 'zawolf_2', { ...revision, payloadHash: 'invalid' });
    await assert.rejects(loadCompanyRemotePolicySnapshot({ db: f.db, companyId: 'zawolf', now: effective }));
    assert.equal(f.writes.length, 0);
  });
}

test('same-instant overlapping revisions are ambiguous', async () => {
  const f = setup();
  f.seed('attendancePolicyHeads', 'zawolf', { companyId: 'zawolf', activeRevision: 1, revision: 3, version: 3,
    scheduledRevisions: [{ revision: 2, revisionId: '2', effectiveFrom: effective.toISOString() },
      { revision: 3, revisionId: '3', effectiveFrom: effective.toISOString() }] });
  await assert.rejects(loadCompanyRemotePolicySnapshot({ db: f.db, companyId: 'zawolf', now: effective }), (error) => error.code === 'policy_scope_ambiguous');
});

test('cross-company head and invalid company fail closed', async () => {
  const f = setup();
  f.seed('attendancePolicyHeads', 'zawolf', { companyId: 'other', activeRevision: 1, scheduledRevisions: [] });
  await assert.rejects(loadCompanyRemotePolicySnapshot({ db: f.db, companyId: 'zawolf', now: effective }), (error) => error.code === 'wrong_company');
  await assert.rejects(loadCompanyRemotePolicySnapshot({ db: f.db, companyId: '../other', now: effective }), (error) => error.code === 'invalid_company');
});
