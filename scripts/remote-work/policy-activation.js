'use strict';

const { normalizedAggregate, policyError, hashPolicyAggregate } = require('./policy-publication');
const { readQualifiedProfile, qualificationMatches, unqualified } = require('./qualification');
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function instant(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T/.test(value)) throw policyError('invalid_effective_date');
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds)) throw policyError('invalid_effective_date');
  return milliseconds;
}

// One transaction owns the head, compatibility projection and calendar guard.
// Revisions are immutable; activation never rewrites a session's policy snapshot.
async function activateDuePolicyRevisions({ db, companyId, now = new Date() }) {
  if (!SAFE_ID.test(String(companyId || ''))) throw policyError('invalid_company');
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) throw policyError('invalid_server_time');
  const headRef = db.collection('attendancePolicyHeads').doc(companyId);
  return db.runTransaction(async (transaction) => {
    const headSnapshot = await transaction.get(headRef);
    if (!headSnapshot.exists) return { status: 'not_due', companyId };
    const head = headSnapshot.data();
    if (head.companyId !== companyId) throw policyError('wrong_company');
    const scheduled = head.scheduledRevisions || [];
    if (!Array.isArray(scheduled) || scheduled.length > 100) throw policyError('invalid_policy_head');
    const entries = scheduled.map((entry) => {
      if (!SAFE_ID.test(String(entry?.revisionId || '')) || !Number.isSafeInteger(entry?.revision) || entry.revision < 1) {
        throw policyError('invalid_policy_head');
      }
      return { ...entry, effectiveAt: instant(entry.effectiveFrom) };
    });
    const due = entries.filter((entry) => entry.effectiveAt <= now.getTime()).sort((a, b) => a.effectiveAt - b.effectiveAt);
    if (!due.length) return { status: 'not_due', companyId };
    if (new Set(entries.map((entry) => entry.effectiveAt)).size !== entries.length) throw policyError('policy_effective_time_conflict');
    const selected = due[due.length - 1];
    const revisionRef = db.collection('attendancePolicyRevisions').doc(`${companyId}_${selected.revisionId}`);
    const revisionSnapshot = await transaction.get(revisionRef);
    if (!revisionSnapshot.exists) throw policyError('revision_not_found');
    const revision = revisionSnapshot.data();
    if (revision.companyId !== companyId || revision.revision !== selected.revision ||
        revision.revisionId !== selected.revisionId || instant(revision.effectiveFrom) !== selected.effectiveAt ||
        !['scheduled', 'published'].includes(revision.state)) throw policyError('invalid_policy_revision');
    const aggregate = normalizedAggregate(revision.aggregate);
    if (hashPolicyAggregate(aggregate) !== revision.payloadHash) throw policyError('policy_snapshot_conflict');
    const qualification = await readQualifiedProfile({ transaction, db, companyId, policy: aggregate.remoteWorkPolicy, now });
    if (qualification && !qualificationMatches(qualification, revision.qualification)) throw unqualified();

    let activeAt = -Infinity;
    if (head.activeRevision > 0) {
      const activeSnapshot = await transaction.get(db.collection('attendancePolicyRevisions').doc(`${companyId}_${head.activeRevision}`));
      if (!activeSnapshot.exists || activeSnapshot.data().companyId !== companyId) throw policyError('invalid_active_revision');
      activeAt = instant(activeSnapshot.data().effectiveFrom);
    }
    const remaining = entries.filter((entry) => entry.effectiveAt > now.getTime()).sort((a, b) => a.effectiveAt - b.effectiveAt)
      .map(({ effectiveAt, ...entry }) => entry);
    const activate = selected.effectiveAt > activeAt;
    const guardRef = db.collection('remoteWorkCalendarGuards').doc(companyId);
    const guardSnapshot = activate ? await transaction.get(guardRef) : null;
    const guard = guardSnapshot?.exists ? guardSnapshot.data() : {};
    if (guard.companyId && guard.companyId !== companyId) throw policyError('wrong_company');
    const nextHead = {
      ...head,
      scheduledRevisions: remaining,
      nextActivationAt: remaining.length ? new Date(remaining[0].effectiveFrom).toISOString() : null,
      version: (head.version || 0) + 1,
      activationRetryAt: null,
      activationFailureCode: null,
      updatedAt: now,
    };
    if (activate) {
      Object.assign(nextHead, { activeRevision: selected.revision, activeEffectiveFrom: revision.effectiveFrom,
        eligibilityEpoch: (head.eligibilityEpoch || 0) + 1 });
      transaction.set(db.collection('companies').doc(companyId), {
        attendancePolicy: aggregate.attendancePolicy, attendancePolicyRevision: selected.revision, updatedAt: now,
      }, { mergeFields: ['attendancePolicy', 'attendancePolicyRevision', 'updatedAt'] });
      transaction.set(guardRef, { ...guard, companyId, epoch: (guard.epoch || 0) + 1,
        version: (guard.version || 0) + 1, policyRevision: selected.revision, updatedAt: now });
      transaction.set(db.collection('remoteWorkAudit').doc(`policy_activation_${companyId}_${selected.revisionId}`), {
        companyId, actorId: 'policy_scheduler', action: 'activate_policy', revisionId: selected.revisionId,
        previousRevision: head.activeRevision || 0, effectiveFrom: revision.effectiveFrom, createdAt: now,
      });
    }
    transaction.set(headRef, nextHead);
    return { status: activate ? 'activated' : 'superseded', companyId, activeRevision: nextHead.activeRevision };
  });
}

// Reuse the existing Hostinger tick; at most ten companies and at most 100
// scheduled references per company are considered. Successful heads leave this
// due query, so the next tick starts with the oldest unresolved activation.
async function queueDuePolicyActivations({ db, now = new Date(), pageSize = 10 }) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) throw policyError('invalid_server_time');
  const limit = Number.isInteger(pageSize) ? Math.max(1, Math.min(10, pageSize)) : 10;
  const snapshot = await db.collection('attendancePolicyHeads')
    .where('nextActivationAt', '<=', now.toISOString()).orderBy('nextActivationAt').limit(limit).get();
  const result = { scanned: 0, activated: 0, superseded: 0, failed: 0 };
  for (const document of snapshot.docs) {
    result.scanned++;
    const observed = document.data();
    try {
      const activation = await activateDuePolicyRevisions({ db, companyId: document.id, now });
      if (activation.status === 'activated') result.activated++;
      if (activation.status === 'superseded') result.superseded++;
    } catch (error) {
      // Defer this operational retry so a page of bad heads cannot starve
      // healthy companies. Never overwrite a head changed since discovery.
      result.failed++;
      await db.runTransaction(async (transaction) => {
        const reference = db.collection('attendancePolicyHeads').doc(document.id);
        const current = await transaction.get(reference);
        if (!current.exists) return;
        const head = current.data();
        if (head.version !== observed.version || head.nextActivationAt !== observed.nextActivationAt) return;
        const retryAt = new Date(now.getTime() + 5 * 60 * 1000).toISOString();
        transaction.set(reference, {
          ...head, nextActivationAt: retryAt, activationRetryAt: retryAt,
          activationFailureCode: /^[a-z_]{1,64}$/.test(error.code || '') ? error.code : 'activation_failed',
        });
      });
    }
  }
  return result;
}

module.exports = { activateDuePolicyRevisions, queueDuePolicyActivations };
