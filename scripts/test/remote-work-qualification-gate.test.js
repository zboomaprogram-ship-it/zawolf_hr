'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryBackend } = require('./helpers/remote-work-fixtures');
const { executeRemotePolicyCommand } = require('../remote-work/policy-publication');
const { activateDuePolicyRevisions } = require('../remote-work/policy-activation');
const now = new Date('2026-11-01T00:00:00.000Z');
const effective = '2026-12-01T00:00:00.000Z';
function fixture({ enabled = true, profile = 'hr_approved_passkey' } = {}) {
  const f = createMemoryBackend({ 'companies/zawolf': { attendancePolicy: { defaultStartTime: '08:00' }, securityPolicy: { keep: true } } });
  const actors = {};
  for (const [uid, capability] of [['editor', 'manage_policy_drafts'], ['reviewer', 'approve_policy'], ['publisher', 'publish_policy']]) {
    const grantId = `qualification_${uid}`;
    f.seed('remoteWorkCapabilityGrants', grantId, { companyId: 'zawolf', actorId: uid, status: 'active',
      scopeType: 'company', scopeId: 'zawolf', capabilities: [capability], version: 1 });
    actors[capability] = { uid, companyId: 'zawolf', active: true, capabilities: [capability], grantIds: { [capability]: [grantId] }, grantVersionsById: { [grantId]: 1 } };
  }
  const remoteWorkPolicy = enabled ? {
    schemaVersion: 1, enabled: true,
    eligibility: { weekStartDay: 6, daysPerWeek: 1, allowedWeekdays: [1, 2, 3], probationEligible: false },
    schedule: { startTime: { mode: 'inherit' }, endTime: { mode: 'inherit' }, checkInOpenTime: { mode: 'inherit' },
      latestCheckoutTime: { mode: 'inherit' }, graceMinutes: { mode: 'inherit' }, quarterDayUntilMinutes: { mode: 'inherit' },
      halfDayUntilMinutes: { mode: 'inherit' }, endDayOffset: 0, checkpoints: [] },
    channels: ['remote_web'], devices: { maxCredentials: 1, reviewIntervalDays: 180, verificationProfile: profile },
    approvals: { schedule: [{ id: 'hr', resolver: 'hr', required: true }] },
    dailyWork: { planRequired: false, summaryRequired: false }, review: { missingCheckpointAction: 'review' },
  } : { schemaVersion: 1, enabled: false };
  const aggregate = { attendancePolicy: { defaultStartTime: '09:00', defaultEndTime: '17:00' }, remoteWorkPolicy };
  const run = (capability, command, when = now) => executeRemotePolicyCommand({ db: f.db, actor: actors[capability], command, now: when });
  async function prepare() {
    await run('manage_policy_drafts', { kind: 'save_policy_draft', operationId: 'save', draftId: 'draft', expectedVersion: 0, payload: { aggregate, effectiveFrom: effective } });
    await run('approve_policy', { kind: 'approve_policy', operationId: 'approve', draftId: 'draft', expectedVersion: 1, payload: { decision: 'approved', reason: 'reviewed' } });
  }
  const publish = () => run('publish_policy', { kind: 'publish_policy', operationId: 'publish', draftId: 'draft', expectedVersion: 2, payload: { effectiveFrom: effective } });
  const qualification = (overrides = {}) => ({ companyId: 'zawolf', profileId: 'hr_approved_passkey', status: 'qualified', version: 1,
    origin: 'https://hr.example.test', rpId: 'hr.example.test', verifiedAt: '2026-10-31T00:00:00.000Z',
    library: '@simplewebauthn/server', libraryVersion: '13.2.0', ...overrides });
  return { ...f, prepare, publish, qualification };
}

test('an enabled remote policy cannot publish without a qualified verification profile', async () => {
  const f = fixture();
  await f.prepare();
  await assert.rejects(f.publish(), (error) => error.code === 'credential_unqualified');
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '08:00');
  assert.equal(f.read('attendancePolicyHeads', 'zawolf'), null);
  assert.equal(f.read('attendancePolicyDrafts', 'zawolf_draft').state, 'draft');
});

for (const overrides of [
  { status: 'revoked' }, { companyId: 'other' }, { profileId: 'other' },
  { origin: 'http://hr.example.test' }, { origin: 'https://evil.test' },
  { libraryVersion: '' }, { verifiedAt: 'invalid' }, { expiresAt: '2026-10-01T00:00:00.000Z' },
]) {
  test(`qualification metadata fails closed: ${JSON.stringify(overrides)}`, async () => {
    const f = fixture();
    await f.prepare();
    f.seed('remoteWorkQualifiedProfiles', 'zawolf_hr_approved_passkey', f.qualification(overrides));
    await assert.rejects(f.publish(), (error) => error.code === 'credential_unqualified');
    assert.equal(f.read('attendancePolicyHeads', 'zawolf'), null);
  });
}

test('a valid scoped qualification allows scheduling with its immutable qualification reference', async () => {
  const f = fixture();
  await f.prepare();
  f.seed('remoteWorkQualifiedProfiles', 'zawolf_hr_approved_passkey', f.qualification());
  const receipt = await f.publish();
  assert.equal(receipt.status, 'scheduled');
  const revision = f.read('attendancePolicyRevisions', 'zawolf_1');
  assert.equal(revision.qualification.profileId, 'hr_approved_passkey');
  assert.equal(revision.qualification.origin, 'https://hr.example.test');
  assert.equal(revision.qualification.rpId, 'hr.example.test');
});

test('a revoked profile blocks scheduled activation without changing the live projection', async () => {
  const f = fixture();
  await f.prepare();
  f.seed('remoteWorkQualifiedProfiles', 'zawolf_hr_approved_passkey', f.qualification());
  await f.publish();
  f.seed('remoteWorkQualifiedProfiles', 'zawolf_hr_approved_passkey', f.qualification({ status: 'revoked' }));
  await assert.rejects(activateDuePolicyRevisions({ db: f.db, companyId: 'zawolf', now: new Date(effective) }), (error) => error.code === 'credential_unqualified');
  assert.equal(f.read('companies', 'zawolf').attendancePolicy.defaultStartTime, '08:00');
  assert.equal(f.read('attendancePolicyHeads', 'zawolf').activeRevision, 0);
});

test('a disabled remote extension can publish without any verification profile', async () => {
  const f = fixture({ enabled: false });
  await f.prepare();
  const receipt = await f.publish();
  assert.equal(receipt.status, 'scheduled');
});

test('qualification comparison ignores document field order but rejects changed evidence', () => {
  const { qualificationMatches } = require('../remote-work/qualification');
  const a = { profileId: 'hr_approved_passkey', version: 1, origin: 'https://example.com', rpId: 'example.com', library: 'example', libraryVersion: '1.0.0', verifiedAt: '2026-01-01T00:00:00Z', expiresAt: null };
  const b = Object.fromEntries(Object.entries(a).reverse());
  assert.equal(qualificationMatches(a, b), true);
  assert.equal(qualificationMatches(a, { ...b, rpId: 'other.com' }), false);
});

test('invalid current or effective server time cannot qualify a profile', async () => {
  const { readQualifiedProfile } = require('../remote-work/qualification');
  const { createMemoryBackend } = require('./helpers/remote-work-fixtures');
  const f = createMemoryBackend();
  f.seed('remoteWorkQualifiedProfiles', 'company_hr_approved_passkey', {
    companyId: 'company', profileId: 'hr_approved_passkey', status: 'qualified', version: 1,
    origin: 'https://example.com', rpId: 'example.com', library: 'example', libraryVersion: '1.0.0',
    verifiedAt: '2026-01-01T00:00:00Z', expiresAt: '2027-01-01T00:00:00Z',
  });
  const call = (now, requiredAt) => f.db.runTransaction(transaction => readQualifiedProfile({
    transaction, db: f.db, companyId: 'company', policy: { enabled: true, devices: { verificationProfile: 'hr_approved_passkey' } }, now, requiredAt,
  }));
  await assert.rejects(call(new Date('invalid'), new Date('2026-11-01')), { code: 'credential_unqualified' });
  await assert.rejects(call(new Date('2026-11-01'), new Date('invalid')), { code: 'credential_unqualified' });
});
