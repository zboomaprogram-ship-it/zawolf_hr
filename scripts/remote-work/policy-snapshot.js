'use strict';

const { isoDate } = require('./eligibility');
const { normalizedAggregate, hashPolicyAggregate, policyError } = require('./policy-publication');
const { resolveRemotePolicy } = require('./policy-resolution');
const { readQualifiedProfile, qualificationMatches, unqualified } = require('./qualification');
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const TIME = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

function effectiveMilliseconds(value) {
  if (typeof value !== 'string' || !isoDate(value.slice(0, 10)) ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) {
    throw policyError('invalid_policy_revision');
  }
  const time = Date.parse(value);
  if (!Number.isFinite(time)) throw policyError('invalid_policy_revision');
  return time;
}

function ensureResolvedPolicy(policy) {
  if (policy.enabled !== true) return;
  const schedule = policy.schedule || {};
  for (const key of ['startTime', 'endTime', 'checkInOpenTime', 'latestCheckoutTime']) {
    if (typeof schedule[key] !== 'string' || !TIME.test(schedule[key])) throw policyError('remote_policy_configuration_incomplete');
  }
  for (const key of ['graceMinutes', 'quarterDayUntilMinutes', 'halfDayUntilMinutes']) {
    if (!Number.isInteger(schedule[key]) || schedule[key] < 0 || schedule[key] > 1440) {
      throw policyError('remote_policy_configuration_incomplete');
    }
  }
  if (schedule.graceMinutes > schedule.quarterDayUntilMinutes || schedule.quarterDayUntilMinutes > schedule.halfDayUntilMinutes) {
    throw policyError('remote_policy_configuration_incomplete');
  }
}

/**
 * Read the company policy effective at an injected server instant without
 * changing the scheduler projection. The future attendance transaction must
 * re-read the returned headVersion/eligibilityEpoch before it commits.
 * Employee scope overrides and historical revision lookup are separate work.
 */
async function loadCompanyRemotePolicySnapshot({ db, companyId, now = new Date() }) {
  if (!SAFE_ID.test(String(companyId || ''))) throw policyError('invalid_company');
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) throw policyError('invalid_server_time');
  return db.runTransaction(async (transaction) => {
    const headSnapshot = await transaction.get(db.collection('attendancePolicyHeads').doc(companyId));
    if (!headSnapshot.exists) throw policyError('remote_policy_missing');
    const head = headSnapshot.data();
    if (head.companyId !== companyId) throw policyError('wrong_company');
    if (!Number.isSafeInteger(head.version) || head.version < 1 ||
        !Number.isSafeInteger(head.activeRevision || 0) || (head.activeRevision || 0) < 0 ||
        !Number.isSafeInteger(head.eligibilityEpoch || 0) || (head.eligibilityEpoch || 0) < 0 ||
        !Array.isArray(head.scheduledRevisions || []) || (head.scheduledRevisions || []).length > 100) {
      throw policyError('invalid_policy_head');
    }
    const pointers = (head.scheduledRevisions || []).map((item) => {
      if (!item || !Number.isSafeInteger(item.revision) || item.revision < 1 ||
          item.revisionId !== String(item.revision)) throw policyError('invalid_policy_head');
      return { ...item, at: effectiveMilliseconds(item.effectiveFrom) };
    });
    if (new Set(pointers.map((item) => item.at)).size !== pointers.length ||
        new Set(pointers.map((item) => item.revision)).size !== pointers.length) {
      throw policyError('policy_scope_ambiguous');
    }
    let active = null;
    if (head.activeRevision > 0) {
      const revisionId = String(head.activeRevision);
      const snapshot = await transaction.get(db.collection('attendancePolicyRevisions').doc(`${companyId}_${revisionId}`));
      active = readRevision(snapshot, { companyId, revision: head.activeRevision, revisionId });
    }
    const due = pointers.filter((item) => item.at <= now.getTime()).sort((a, b) => a.at - b.at);
    const next = due.at(-1);
    let selected = active && active.at <= now.getTime() ? active : null;
    if (next && selected?.at === next.at && selected.revision !== next.revision) throw policyError('policy_scope_ambiguous');
    if (next && (!selected || next.at > selected.at)) {
      const snapshot = await transaction.get(db.collection('attendancePolicyRevisions').doc(`${companyId}_${next.revisionId}`));
      selected = readRevision(snapshot, { companyId, revision: next.revision, revisionId: next.revisionId, expectedAt: next.at });
    }
    if (!selected) throw policyError(active ? 'historical_policy_unavailable' : 'remote_policy_missing');
    const qualification = await readQualifiedProfile({ transaction, db, companyId, policy: selected.aggregate.remoteWorkPolicy, now });
    if (qualification && !qualificationMatches(qualification, selected.qualification)) throw unqualified();
    const resolved = resolveRemotePolicy({ sharedAttendancePolicy: selected.aggregate.attendancePolicy,
      scopes: [{ scope: 'company', revisionId: `${companyId}_${selected.revisionId}`, policy: selected.aggregate.remoteWorkPolicy }] });
    ensureResolvedPolicy(resolved.policy);
    return {
      companyId, revision: selected.revision, revisionId: selected.revisionId,
      effectiveFrom: selected.effectiveFrom, aggregate: selected.aggregate,
      policy: resolved.policy, sourceRevisionIds: resolved.sourceRevisionIds, hash: resolved.hash,
      headVersion: head.version, eligibilityEpoch: head.eligibilityEpoch || 0,
    };
  });
}

function readRevision(snapshot, { companyId, revision, revisionId, expectedAt }) {
  if (!snapshot.exists) throw policyError('revision_not_found');
  const value = snapshot.data() || {};
  if (value.companyId !== companyId || value.revision !== revision || value.revisionId !== revisionId ||
      !['published', 'scheduled'].includes(value.state)) throw policyError('invalid_policy_revision');
  const at = effectiveMilliseconds(value.effectiveFrom);
  if (expectedAt !== undefined && at !== expectedAt) throw policyError('invalid_policy_revision');
  const aggregate = normalizedAggregate(value.aggregate);
  if (!value.payloadHash || value.payloadHash !== hashPolicyAggregate(aggregate)) throw policyError('policy_snapshot_conflict');
  return { revision, revisionId, effectiveFrom: value.effectiveFrom, at, aggregate, qualification: value.qualification };
}

module.exports = { loadCompanyRemotePolicySnapshot };
