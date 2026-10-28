const test = require('node:test');
const assert = require('node:assert/strict');
const { validateRemotePolicy } = require('../remote-work/policy-schema');
const { resolveRemotePolicy, mergePolicy } = require('../remote-work/policy-resolution');
const { executeRemotePolicyCommand } = require('../remote-work/policy-publication');

const policy = (overrides = {}) => ({
  schemaVersion: 1,
  enabled: true,
  eligibility: {
    weekStartDay: 6,
    daysPerWeek: 1,
    allowedWeekdays: [6, 1, 2, 3, 4],
    probationEligible: false,
  },
  schedule: {
    startTime: { mode: 'inherit' },
      endTime: { mode: 'override', value: '18:30' },
      checkInOpenTime: { mode: 'inherit' },
      latestCheckoutTime: { mode: 'inherit' },
      graceMinutes: { mode: 'inherit' },
      quarterDayUntilMinutes: { mode: 'inherit' },
      halfDayUntilMinutes: { mode: 'inherit' },
      endDayOffset: 0,
      checkpoints: [],
  },
  channels: ['remote_web'],
  devices: { maxCredentials: 1, reviewIntervalDays: 180, verificationProfile: 'hr_approved_passkey' },
  approvals: { schedule: [{ id: 'hr', resolver: 'hr', required: true }] },
  dailyWork: { planRequired: false, summaryRequired: false },
  review: { missingCheckpointAction: 'review', dailyFinancialCap: 0 },
  ...overrides,
});

function fakeDb(initial = {}) {
  const docs = new Map(Object.entries(initial));
  const ref = (path) => ({ path });
  return {
    docs,
    collection: (name) => ({ doc: (id) => ref(`${name}/${id}`) }),
    runTransaction: async (callback) => callback({
      get: async (reference) => ({ exists: docs.has(reference.path), data: () => docs.get(reference.path) }),
      set: (reference, value, options = {}) => {
        const previous = docs.get(reference.path) || {};
        docs.set(reference.path, options.merge ? { ...previous, ...value } : value);
      },
      create: (reference, value) => {
        if (docs.has(reference.path)) throw new Error('already-exists');
        docs.set(reference.path, value);
      },
    }),
  };
}

const aggregate = () => ({
  attendancePolicy: { defaultStartTime: '09:00', defaultEndTime: '17:00', graceMinutes: 10 },
  remoteWorkPolicy: policy(),
});

const remoteGrant = (actorId, capability, version = 1) => ({
  companyId: 'zawolf', actorId, status: 'active', scopeType: 'company', scopeId: 'zawolf',
  capabilities: [capability], version,
});

const qualifiedProfileFixture = {
  companyId: 'zawolf', profileId: 'hr_approved_passkey', status: 'qualified', version: 1,
  origin: 'https://hr.example.test', rpId: 'hr.example.test',
  verifiedAt: '2026-10-31T00:00:00.000Z', library: '@simplewebauthn/server', libraryVersion: '13.2.0',
};

const actorWithGrant = (uid, capability, grantId) => ({
  uid, companyId: 'zawolf', active: true, capabilities: [capability],
  grantIds: { [capability]: [grantId] },
  grantVersionsById: { [grantId]: 1 },
});

test('policy schema accepts policy-defined allowances and any checkpoint count', () => {
  const value = policy({
    eligibility: {
      weekStartDay: 2,
      daysPerWeek: 3,
      allowedWeekdays: [2, 3, 4, 5],
      probationEligible: true,
    },
    schedule: {
      startTime: { mode: 'inherit' },
      endTime: { mode: 'override', value: '23:30' },
      checkInOpenTime: { mode: 'inherit' },
      latestCheckoutTime: { mode: 'inherit' },
      graceMinutes: { mode: 'inherit' },
      quarterDayUntilMinutes: { mode: 'inherit' },
      halfDayUntilMinutes: { mode: 'inherit' },
      endDayOffset: 1,
      checkpoints: Array.from({ length: 5 }, (_, index) => ({
        id: `slot_${index + 1}`,
        label: `Update ${index + 1}`,
        dueTime: `${String(9 + index).padStart(2, '0')}:15`,
        graceMinutes: index * 5,
      })),
    },
  });
  assert.deepEqual(validateRemotePolicy(value), { valid: true, errors: [] });
});

test('policy schema rejects unsupported executable rules and malformed windows', () => {
  const result = validateRemotePolicy(policy({
    schedule: {
      startTime: { mode: 'override', value: '28:00' },
      endTime: { mode: 'override', value: '18:30' },
      endDayOffset: 3,
      checkpoints: [
        { id: 'same', dueTime: '10:00', graceMinutes: -1 },
        { id: 'same', dueTime: '10:00', graceMinutes: 1 },
      ],
    },
    eligibility: { weekStartDay: 9, daysPerWeek: 4, allowedWeekdays: [1], probationEligible: true },
    expression: 'return true',
    notifications: { script: 'deleteAll()' },
  }));
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((error) => error.path === 'schedule.startTime.value'));
  assert.ok(result.errors.some((error) => error.path === 'schedule.endDayOffset'));
  assert.ok(result.errors.some((error) => error.path === 'schedule.checkpoints[1].id'));
  assert.ok(result.errors.some((error) => error.path === 'expression'));
  assert.ok(result.errors.some((error) => error.path === 'notifications.script'));
});

test('policy validation enforces dynamic notification and financial boundaries', () => {
  const invalid = validateRemotePolicy(policy({
    notifications: { enabled: true, reminderLeadMinutes: 1441 },
    review: { missingCheckpointAction: 'pending_financial_review', dailyFinancialCap: 0 },
  }));
  assert.equal(invalid.valid, false);
  assert.ok(invalid.errors.some((error) => error.path === 'notifications.reminderLeadMinutes'));
  assert.ok(invalid.errors.some((error) => error.path === 'review.dailyFinancialCap'));

  const valid = validateRemotePolicy(policy({
    notifications: { enabled: false, reminderLeadMinutes: 0 },
    review: { missingCheckpointAction: 'none', dailyFinancialCap: 0 },
    privacy: { retentionDays: { workEvidenceDays: 365, auditDays: 1825 } },
  }));
  assert.deepEqual(valid, { valid: true, errors: [] });
});

test('resolution follows scope precedence, inherits shared settings and replaces lists', () => {
  const resolved = resolveRemotePolicy({
    sharedAttendancePolicy: { defaultStartTime: '09:00', defaultEndTime: '17:00', graceMinutes: 10 },
    scopes: [
      { scope: 'company', revisionId: 'c1', policy: policy({ schedule: { startTime: { mode: 'inherit' }, endTime: { mode: 'inherit' }, checkpoints: [{ id: 'a', dueTime: '12:00', graceMinutes: 5 }] } }) },
      { scope: 'department', revisionId: 'd2', policy: { eligibility: { weekStartDay: 6, daysPerWeek: 2, allowedWeekdays: [6, 1, 2], probationEligible: false } } },
      { scope: 'employee', revisionId: 'e3', policy: { schedule: { startTime: { mode: 'override', value: '10:00' }, endTime: { mode: 'inherit' }, checkpoints: [] } } },
    ],
    datedException: null,
  });
  assert.equal(resolved.policy.eligibility.daysPerWeek, 2);
  assert.equal(resolved.policy.schedule.startTime, '10:00');
  assert.equal(resolved.policy.schedule.endTime, '17:00');
  assert.deepEqual(resolved.policy.schedule.checkpoints, []);
  assert.deepEqual(resolved.sourceRevisionIds, ['c1', 'd2', 'e3']);
  assert.match(resolved.hash, /^[a-f0-9]{64}$/);
});

test('draft save is versioned, idempotent and does not change published projection', async () => {
  const db = fakeDb({
    'companies/zawolf': { attendancePolicy: { defaultStartTime: '08:00' } },
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
  });
  const actor = actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft');
  const command = {
    operationId: 'save-1', kind: 'save_policy_draft', draftId: 'draft-1',
    expectedVersion: 0, payload: { aggregate: aggregate(), effectiveFrom: '2026-12-01T00:00:00Z' },
  };
  const first = await executeRemotePolicyCommand({ db, actor, command, now: new Date('2026-11-01T00:00:00Z') });
  const retry = await executeRemotePolicyCommand({ db, actor, command, now: new Date('2026-11-01T00:01:00Z') });
  assert.equal(first.draftId, 'draft-1');
  assert.deepEqual(retry, first);
  assert.equal(db.docs.get('companies/zawolf').attendancePolicy.defaultStartTime, '08:00');
  assert.equal(db.docs.get('attendancePolicyDrafts/zawolf_draft-1').version, 1);
});

test('policy command rechecks the grant version transactionally', async () => {
  const db = fakeDb({
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts', 2),
  });
  const staleActor = actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft');
  await assert.rejects(
    executeRemotePolicyCommand({
      db,
      actor: staleActor,
      command: {
        operationId: 'stale-grant', kind: 'save_policy_draft', draftId: 'draft',
        expectedVersion: 0, payload: { aggregate: aggregate() },
      },
      now: new Date('2026-11-01T00:00:00Z'),
    }),
    (error) => error.code === 'not_authorized',
  );
  assert.equal(db.docs.has('attendancePolicyDrafts/zawolf_draft'), false);
});

test('publication requires a different approver and publisher then writes one revision projection', async () => {
  const db = fakeDb({
    'remoteWorkQualifiedProfiles/zawolf_hr_approved_passkey': qualifiedProfileFixture,
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
    'remoteWorkCapabilityGrants/approver-approval': remoteGrant('approver', 'approve_policy'),
    'remoteWorkCapabilityGrants/approver-publish': remoteGrant('approver', 'publish_policy'),
    'remoteWorkCapabilityGrants/publisher-publish': remoteGrant('publisher', 'publish_policy'),
  });
  const editor = actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft');
  const approver = {
    ...actorWithGrant('approver', 'approve_policy', 'approver-approval'),
    capabilities: ['approve_policy', 'publish_policy'],
    grantIds: { approve_policy: ['approver-approval'], publish_policy: ['approver-publish'] },
    grantVersionsById: { 'approver-approval': 1, 'approver-publish': 1 },
  };
  const publisher = actorWithGrant('publisher', 'publish_policy', 'publisher-publish');
  const now = new Date('2026-11-01T00:00:00Z');
  await executeRemotePolicyCommand({ db, actor: editor, now, command: {
    operationId: 'draft-op', kind: 'save_policy_draft', draftId: 'd1', expectedVersion: 0,
    payload: { aggregate: aggregate(), effectiveFrom: '2026-11-01T00:00:00Z' },
  } });
  await executeRemotePolicyCommand({ db, actor: approver, now, command: {
    operationId: 'approve-op', kind: 'approve_policy', draftId: 'd1', expectedVersion: 1,
    payload: { decision: 'approved', reason: 'راجعت الإعدادات' },
  } });
  await assert.rejects(
    executeRemotePolicyCommand({ db, actor: approver, now, command: {
      operationId: 'self-publish', kind: 'publish_policy', draftId: 'd1', expectedVersion: 2,
      payload: { effectiveFrom: '2026-11-01T00:00:00Z' },
    } }),
    (error) => error.code === 'policy_publisher_must_differ',
  );
  const result = await executeRemotePolicyCommand({ db, actor: publisher, now, command: {
    operationId: 'publish-op', kind: 'publish_policy', draftId: 'd1', expectedVersion: 2,
    payload: { effectiveFrom: '2026-11-01T00:00:00Z' },
  } });
  assert.equal(result.revision, 1);
  assert.equal(result.version, 3);
  assert.equal(db.docs.get('attendancePolicyHeads/zawolf').revision, 1);
  assert.equal(db.docs.get('companies/zawolf').attendancePolicy.defaultStartTime, '09:00');
  assert.equal(db.docs.get('attendancePolicyRevisions/zawolf_1').aggregate.remoteWorkPolicy.enabled, true);
});

test('future policy publication stays scheduled and leaves the active projection unchanged', async () => {
  const db = fakeDb({
    'remoteWorkQualifiedProfiles/zawolf_hr_approved_passkey': qualifiedProfileFixture,
    'companies/zawolf': { attendancePolicy: { defaultStartTime: '08:00' } },
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
    'remoteWorkCapabilityGrants/approver-approval': remoteGrant('approver', 'approve_policy'),
    'remoteWorkCapabilityGrants/publisher-publish': remoteGrant('publisher', 'publish_policy'),
  });
  const editor = actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft');
  const approver = actorWithGrant('approver', 'approve_policy', 'approver-approval');
  const publisher = actorWithGrant('publisher', 'publish_policy', 'publisher-publish');
  const now = new Date('2026-11-01T00:00:00Z');
  await executeRemotePolicyCommand({ db, actor: editor, now, command: {
    operationId: 'draft-future', kind: 'save_policy_draft', draftId: 'future', expectedVersion: 0,
    payload: { aggregate: aggregate(), effectiveFrom: '2026-12-01T00:00:00Z' },
  } });
  await executeRemotePolicyCommand({ db, actor: approver, now, command: {
    operationId: 'approve-future', kind: 'approve_policy', draftId: 'future', expectedVersion: 1,
    payload: { decision: 'approved', reason: 'مراجعة مستقلة' },
  } });
  const result = await executeRemotePolicyCommand({ db, actor: publisher, now, command: {
    operationId: 'publish-future', kind: 'publish_policy', draftId: 'future', expectedVersion: 2,
    payload: { effectiveFrom: '2026-12-01T00:00:00Z' },
  } });
  assert.equal(result.status, 'scheduled');
  assert.equal(db.docs.get('companies/zawolf').attendancePolicy.defaultStartTime, '08:00');
  assert.equal(db.docs.get('attendancePolicyHeads/zawolf').activeRevision, 0);
  assert.equal(db.docs.get('attendancePolicyRevisions/zawolf_1').state, 'scheduled');
  assert.equal(db.docs.get('attendancePolicyDrafts/zawolf_future').state, 'scheduled');
});

test('changing draft effective time invalidates approval of the old publication date', async () => {
  const db = fakeDb({
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
    'remoteWorkCapabilityGrants/reviewer-approval': remoteGrant('reviewer', 'approve_policy'),
  });
  const editor = actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft');
  const reviewer = actorWithGrant('reviewer', 'approve_policy', 'reviewer-approval');
  const now = new Date('2026-11-01T00:00:00Z');
  const save = (operationId, expectedVersion, effectiveFrom) => executeRemotePolicyCommand({ db, actor: editor, now, command: {
    operationId, kind: 'save_policy_draft', draftId: 'date_review', expectedVersion,
    payload: { aggregate: aggregate(), effectiveFrom },
  } });
  await save('save_date', 0, '2026-12-01T00:00:00Z');
  await executeRemotePolicyCommand({ db, actor: reviewer, now, command: {
    operationId: 'approve_date', kind: 'approve_policy', draftId: 'date_review', expectedVersion: 1,
    payload: { decision: 'approved', reason: 'Reviewed December 1 impact' },
  } });
  assert.equal(db.docs.get('attendancePolicyDrafts/zawolf_date_review').approvals.length, 1);
  await save('change_date', 2, '2026-11-02T00:00:00Z');
  assert.deepEqual(db.docs.get('attendancePolicyDrafts/zawolf_date_review').approvals, []);
});

test('publisher cannot substitute a different effective time after independent approval', async () => {
  const db = fakeDb({
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
    'remoteWorkCapabilityGrants/reviewer-approval': remoteGrant('reviewer', 'approve_policy'),
    'remoteWorkCapabilityGrants/publisher-publish': remoteGrant('publisher', 'publish_policy'),
  });
  const now = new Date('2026-11-01T00:00:00Z');
  await executeRemotePolicyCommand({ db, actor: actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft'), now, command: {
    operationId: 'review_save', kind: 'save_policy_draft', draftId: 'review_date', expectedVersion: 0,
    payload: { aggregate: aggregate(), effectiveFrom: '2026-12-01T00:00:00Z' },
  } });
  await executeRemotePolicyCommand({ db, actor: actorWithGrant('reviewer', 'approve_policy', 'reviewer-approval'), now, command: {
    operationId: 'review_approve', kind: 'approve_policy', draftId: 'review_date', expectedVersion: 1,
    payload: { decision: 'approved', reason: 'Reviewed' },
  } });
  await assert.rejects(executeRemotePolicyCommand({ db, actor: actorWithGrant('publisher', 'publish_policy', 'publisher-publish'), now, command: {
    operationId: 'review_substitute', kind: 'publish_policy', draftId: 'review_date', expectedVersion: 2,
    payload: { effectiveFrom: now.toISOString() },
  } }), (error) => error.code === 'policy_review_changed');
  assert.equal(db.docs.has('attendancePolicyHeads/zawolf'), false);
});

test('published draft cannot be reopened by a later save', async () => {
  const db = fakeDb({
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
    'attendancePolicyDrafts/zawolf_locked': { companyId: 'zawolf', state: 'published', version: 3, aggregate: aggregate(), approvals: [] },
  });
  await assert.rejects(executeRemotePolicyCommand({ db, actor: actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft'), command: {
    operationId: 'reopen', kind: 'save_policy_draft', draftId: 'locked', expectedVersion: 3,
    payload: { aggregate: aggregate() },
  } }), (error) => error.code === 'draft_not_editable');
  assert.equal(db.docs.get('attendancePolicyDrafts/zawolf_locked').state, 'published');
});

test('publication rechecks the reviewed content hash rather than trusting its stored label', async () => {
  const db = fakeDb({
    'remoteWorkCapabilityGrants/editor-draft': remoteGrant('editor', 'manage_policy_drafts'),
    'remoteWorkCapabilityGrants/reviewer-approval': remoteGrant('reviewer', 'approve_policy'),
    'remoteWorkCapabilityGrants/publisher-publish': remoteGrant('publisher', 'publish_policy'),
  });
  const now = new Date('2026-11-01T00:00:00Z');
  await executeRemotePolicyCommand({ db, actor: actorWithGrant('editor', 'manage_policy_drafts', 'editor-draft'), now, command: {
    operationId: 'hash_save', kind: 'save_policy_draft', draftId: 'hash_review', expectedVersion: 0,
    payload: { aggregate: aggregate(), effectiveFrom: '2026-12-01T00:00:00Z' },
  } });
  await executeRemotePolicyCommand({ db, actor: actorWithGrant('reviewer', 'approve_policy', 'reviewer-approval'), now, command: {
    operationId: 'hash_approve', kind: 'approve_policy', draftId: 'hash_review', expectedVersion: 1,
    payload: { decision: 'approved', reason: 'Reviewed original content' },
  } });
  db.docs.get('attendancePolicyDrafts/zawolf_hash_review').aggregate.attendancePolicy.defaultStartTime = '12:00';
  await assert.rejects(executeRemotePolicyCommand({ db, actor: actorWithGrant('publisher', 'publish_policy', 'publisher-publish'), now, command: {
    operationId: 'hash_publish', kind: 'publish_policy', draftId: 'hash_review', expectedVersion: 2,
    payload: { effectiveFrom: '2026-12-01T00:00:00Z' },
  } }), (error) => error.code === 'policy_review_changed');
  assert.equal(db.docs.has('attendancePolicyHeads/zawolf'), false);
});

test('enabled policy rejects unsupported verification profile names', () => {
  const value = policy({ devices: { maxCredentials: 1, reviewIntervalDays: 180, verificationProfile: 'unverified_fake_profile' } });
  const result = validateRemotePolicy(value);
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((error) => error.path === 'devices.verificationProfile' && error.code === 'unsupported_profile'));
});

test('challenge lifetime accepts policy settings only inside server security bounds', () => {
  for (const ttl of [1, 120, 180, 300]) {
    const result = validateRemotePolicy(policy({ devices: { maxCredentials: 1, reviewIntervalDays: 180, verificationProfile: 'hr_approved_passkey', challengeTtlSeconds: ttl } }));
    assert.equal(result.valid, true, JSON.stringify(result.errors));
  }
  for (const ttl of [0, 301, 1.5, '120']) {
    const result = validateRemotePolicy(policy({ devices: { maxCredentials: 1, reviewIntervalDays: 180, verificationProfile: 'hr_approved_passkey', challengeTtlSeconds: ttl } }));
    assert.ok(result.errors.some(error => error.path === 'devices.challengeTtlSeconds' && error.code === 'range'));
  }
});

test('policy resolution rejects unsafe property names without modifying object prototypes', () => {
  const unsafe = JSON.parse('{"__proto__":{"remotePolicyPolluted":true}}');
  try {
    assert.throws(() => resolveRemotePolicy({ scopes: [{ scope: 'company', policy: unsafe }] }),
      (error) => error.code === 'invalid_policy');
    assert.throws(() => mergePolicy({}, { checkpoints: [unsafe] }), (error) => error.code === 'invalid_policy');
    assert.throws(() => resolveRemotePolicy({ scopes: [{ scope: 'company', policy: {} }], datedException: { policy: { nested: unsafe } } }),
      (error) => error.code === 'invalid_policy');
    assert.equal({}.remotePolicyPolluted, undefined);
  } finally {
    delete Object.prototype.remotePolicyPolluted;
  }
});
