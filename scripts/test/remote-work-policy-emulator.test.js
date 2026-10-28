'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { executeRemotePolicyCommand } = require('../remote-work/policy-publication');

test('concurrent policy publishers commit one revision and committed retries return its receipt', {
  skip: process.env.RUN_REMOTE_WORK_EMULATOR !== '1',
}, async () => {
  const harness = await createRemoteHarness({ backend: 'emulator' });
  const companyId = 'policy_race_fixture';
  const now = new Date('2026-11-01T00:00:00Z');
  const actors = {};
  try {
    await harness.seed('companies', companyId, {
      attendancePolicy: { defaultStartTime: '07:00', retiredRestriction: true },
      securityPolicy: { keep: true },
    });
    for (const [uid, capability] of [
      ['race_editor', 'manage_policy_drafts'], ['race_reviewer', 'approve_policy'], ['race_publisher', 'publish_policy'],
    ]) {
      const grantId = `${uid}_grant`;
      await harness.seed('remoteWorkCapabilityGrants', grantId, {
        companyId, actorId: uid, status: 'active', scopeType: 'company', scopeId: companyId,
        capabilities: [capability], version: 1,
      });
      actors[capability] = {
        uid, companyId, active: true, capabilities: [capability],
        grantIds: { [capability]: [grantId] }, grantVersionsById: { [grantId]: 1 },
      };
    }
    const execute = (capability, command) => executeRemotePolicyCommand({ db: harness.db, actor: actors[capability], now, command });
    await execute('manage_policy_drafts', {
      operationId: 'create', kind: 'save_policy_draft', draftId: 'race', expectedVersion: 0,
      payload: { aggregate: {
        attendancePolicy: { defaultStartTime: '08:30', reminderExtension: { enabled: true } },
        remoteWorkPolicy: { schemaVersion: 1, enabled: false },
      } },
    });
    await execute('approve_policy', {
      operationId: 'approve', kind: 'approve_policy', draftId: 'race', expectedVersion: 1,
      payload: { decision: 'approved', reason: 'Reviewed fixture' },
    });
    const command = (operationId) => ({
      operationId, kind: 'publish_policy', draftId: 'race', expectedVersion: 2,
      payload: { effectiveFrom: now.toISOString() },
    });
    const results = await Promise.allSettled([
      execute('publish_policy', command('publish_a')),
      execute('publish_policy', command('publish_b')),
    ]);
    const successful = results.filter((result) => result.status === 'fulfilled');
    const rejected = results.filter((result) => result.status === 'rejected');
    assert.equal(successful.length, 1);
    assert.equal(rejected.length, 1);
    assert.equal(rejected[0].reason.code, 'version_conflict');
    const receipt = successful[0].value;
    assert.equal(receipt.revision, 1);
    assert.equal(receipt.version, 3);
    assert.deepEqual(await execute('publish_policy', command(receipt.operationId)), receipt);
    const revisions = await harness.db.collection('attendancePolicyRevisions').where('companyId', '==', companyId).get();
    assert.equal(revisions.size, 1);
    const company = await harness.read('companies', companyId);
    assert.equal(company.attendancePolicyRevision, 1);
    assert.equal(company.attendancePolicy.defaultStartTime, '08:30');
    assert.equal(company.attendancePolicy.retiredRestriction, undefined);
    assert.deepEqual(company.securityPolicy, { keep: true });
    assert.deepEqual(company.attendancePolicy.reminderExtension, { enabled: true });
    const draft = await harness.read('attendancePolicyDrafts', `${companyId}_race`);
    assert.equal(draft.version, 3);
    assert.equal(draft.state, 'published');
    const losingOperation = receipt.operationId === 'publish_a' ? 'publish_b' : 'publish_a';
    assert.equal(await harness.read('attendancePolicyOperations', `${companyId}_race_publisher_${losingOperation}`), null);
  } finally { await harness.close(); }
});

test('scheduled activation is atomic under real Firestore contention and the due query advances', {
  skip: process.env.RUN_REMOTE_WORK_EMULATOR !== '1',
}, async () => {
  const { activateDuePolicyRevisions, queueDuePolicyActivations } = require('../remote-work/policy-activation');
  const { hashPolicyAggregate } = require('../remote-work/policy-publication');
  const harness = await createRemoteHarness({ backend: 'emulator' });
  const effectiveFrom = '2026-12-01T00:00:00.000Z';
  const now = new Date(effectiveFrom);
  try {
    for (const companyId of ['activation_race_fixture', 'activation_worker_fixture']) {
      const aggregate = { attendancePolicy: { defaultStartTime: '10:30', remoteWorkPolicy: { schemaVersion: 1, enabled: false } },
        remoteWorkPolicy: { schemaVersion: 1, enabled: false } };
      await harness.seed('companies', companyId, { attendancePolicy: { defaultStartTime: '08:00', retiredRestriction: true }, securityPolicy: { keep: true } });
      await harness.seed('attendancePolicyRevisions', `${companyId}_1`, { companyId, revision: 1, revisionId: '1',
        aggregate, payloadHash: hashPolicyAggregate(aggregate), effectiveFrom, state: 'scheduled' });
      await harness.seed('attendancePolicyHeads', companyId, { companyId, revision: 1, activeRevision: 0, version: 1,
        eligibilityEpoch: 0, nextActivationAt: effectiveFrom, scheduledRevisions: [{ revision: 1, revisionId: '1', effectiveFrom }] });
    }
    const results = await Promise.all([
      activateDuePolicyRevisions({ db: harness.db, companyId: 'activation_race_fixture', now }),
      activateDuePolicyRevisions({ db: harness.db, companyId: 'activation_race_fixture', now }),
    ]);
    assert.deepEqual(results.map((result) => result.status).sort(), ['activated', 'not_due']);
    assert.equal((await harness.read('remoteWorkCalendarGuards', 'activation_race_fixture')).epoch, 1);
    const batch = await queueDuePolicyActivations({ db: harness.db, now, pageSize: 1 });
    assert.equal(batch.scanned, 1);
    assert.equal(batch.activated, 1);
    assert.equal(batch.failed, 0);
    assert.deepEqual((await harness.read('companies', 'activation_worker_fixture')).securityPolicy, { keep: true });
    assert.equal((await harness.read('companies', 'activation_worker_fixture')).attendancePolicy.defaultStartTime, '10:30');
    assert.equal((await harness.read('companies', 'activation_worker_fixture')).attendancePolicy.retiredRestriction, undefined);
    const empty = await queueDuePolicyActivations({ db: harness.db, now, pageSize: 1 });
    assert.equal(empty.scanned, 0);
  } finally { await harness.close(); }
});

test('qualification gate applies to real transactions and revoked scheduled policies', {
  skip: process.env.RUN_REMOTE_WORK_EMULATOR !== '1',
}, async () => {
  const { activateDuePolicyRevisions } = require('../remote-work/policy-activation');
  const harness = await createRemoteHarness({ backend: 'emulator' });
  const companyId = 'qualification_emulator_fixture';
  const now = new Date('2026-11-01T00:00:00.000Z');
  const effectiveFrom = '2026-12-01T00:00:00.000Z';
  const actors = {};
  try {
    await harness.seed('companies', companyId, { attendancePolicy: { defaultStartTime: '08:00' }, securityPolicy: { keep: true } });
    for (const [uid, capability] of [['q_editor', 'manage_policy_drafts'], ['q_reviewer', 'approve_policy'], ['q_publisher', 'publish_policy']]) {
      const grantId = `${uid}_grant`;
      await harness.seed('remoteWorkCapabilityGrants', grantId, { companyId, actorId: uid, status: 'active', scopeType: 'company', scopeId: companyId, capabilities: [capability], version: 1 });
      actors[capability] = { uid, companyId, active: true, capabilities: [capability], grantIds: { [capability]: [grantId] }, grantVersionsById: { [grantId]: 1 } };
    }
    const run = (capability, command) => executeRemotePolicyCommand({ db: harness.db, actor: actors[capability], now, command });
    const remoteWorkPolicy = {
      schemaVersion: 1, enabled: true,
      eligibility: { weekStartDay: 6, daysPerWeek: 1, allowedWeekdays: [1, 2, 3], probationEligible: false },
      schedule: { startTime: { mode: 'inherit' }, endTime: { mode: 'inherit' }, checkInOpenTime: { mode: 'inherit' }, latestCheckoutTime: { mode: 'inherit' }, graceMinutes: { mode: 'inherit' }, quarterDayUntilMinutes: { mode: 'inherit' }, halfDayUntilMinutes: { mode: 'inherit' }, endDayOffset: 0, checkpoints: [] },
      channels: ['remote_web'], devices: { maxCredentials: 1, reviewIntervalDays: 180, verificationProfile: 'hr_approved_passkey' },
      approvals: { schedule: [{ id: 'hr', resolver: 'hr', required: true }] }, dailyWork: { planRequired: false, summaryRequired: false }, review: { missingCheckpointAction: 'review' },
    };
    await run('manage_policy_drafts', { kind: 'save_policy_draft', operationId: 'q_save', draftId: 'q', expectedVersion: 0, payload: { effectiveFrom, aggregate: { attendancePolicy: {
      defaultStartTime: '09:00', defaultEndTime: '17:00', checkInOpenTime: '08:45', latestCheckoutTime: '18:00',
      graceMinutes: 15, quarterDayUntilMinutes: 30, halfDayUntilMinutes: 60,
    }, remoteWorkPolicy } } });
    await run('approve_policy', { kind: 'approve_policy', operationId: 'q_review', draftId: 'q', expectedVersion: 1, payload: { decision: 'approved', reason: 'test review' } });
    const publish = () => run('publish_policy', { kind: 'publish_policy', operationId: 'q_publish', draftId: 'q', expectedVersion: 2, payload: { effectiveFrom } });
    await assert.rejects(publish(), (error) => error.code === 'credential_unqualified');
    assert.equal(await harness.read('attendancePolicyHeads', companyId), null);
    const profileId = 'hr_approved_passkey';
    const qualified = { companyId, profileId, status: 'qualified', version: 1, origin: 'https://hr.example.test', rpId: 'hr.example.test', verifiedAt: '2026-10-31T00:00:00.000Z', library: '@simplewebauthn/server', libraryVersion: '13.2.0' };
    await harness.seed('remoteWorkQualifiedProfiles', `${companyId}_${profileId}`, qualified);
    assert.equal((await publish()).status, 'scheduled');
    const { loadCompanyRemotePolicySnapshot } = require('../remote-work/policy-snapshot');
    const snapshot = await loadCompanyRemotePolicySnapshot({ db: harness.db, companyId, now: new Date(effectiveFrom) });
    assert.equal(snapshot.revision, 1);
    assert.equal(snapshot.policy.schedule.startTime, '09:00');
    await harness.seed('remoteWorkQualifiedProfiles', `${companyId}_${profileId}`, { ...qualified, status: 'revoked' });
    await assert.rejects(activateDuePolicyRevisions({ db: harness.db, companyId, now: new Date(effectiveFrom) }), (error) => error.code === 'credential_unqualified');
    assert.equal((await harness.read('companies', companyId)).attendancePolicy.defaultStartTime, '08:00');
    assert.equal((await harness.read('attendancePolicyHeads', companyId)).activeRevision, 0);
  } finally { await harness.close(); }
});
