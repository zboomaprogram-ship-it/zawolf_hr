'use strict';

const crypto = require('node:crypto');
const { validateRemotePolicy } = require('./policy-schema');
const { readQualifiedProfile } = require('./qualification');

const COMMAND_CAPABILITIES = Object.freeze({
  save_policy_draft: 'manage_policy_drafts',
  approve_policy: 'approve_policy',
  publish_policy: 'publish_policy',
  revert_policy: 'manage_policy_drafts',
});
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function policyError(code, messageAr = 'تعذر تنفيذ تحديث السياسة.') {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object' && !(value instanceof Date)) {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  }
  return value;
}

function hash(value) {
  return crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
}

function requireActor(actor, capability) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw policyError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
  if (!Array.isArray(actor.capabilities) || !actor.capabilities.includes(capability)) {
    throw policyError('not_authorized', 'لا تملك الصلاحية المطلوبة لإدارة سياسة الدوام.');
  }
  if (!Array.isArray(actor.grantIds?.[capability]) || actor.grantIds[capability].length === 0) {
    throw policyError('not_authorized', 'لا يوجد سجل صلاحية ساري لهذا الإجراء.');
  }
}

function validateCommand(command) {
  if (!command || !['save_policy_draft', 'approve_policy', 'publish_policy', 'revert_policy'].includes(command.kind)) {
    throw policyError('invalid_command', 'نوع أمر السياسة غير مدعوم.');
  }
  if (!SAFE_ID.test(String(command.operationId || '')) || !SAFE_ID.test(String(command.draftId || ''))) {
    throw policyError('invalid_command', 'معرف عملية السياسة غير صالح.');
  }
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 0) {
    throw policyError('invalid_command', 'إصدار المسودة المطلوب غير صالح.');
  }
}

function normalizedAggregate(input) {
  const aggregate = input?.aggregate || input;
  if (!aggregate || typeof aggregate !== 'object' || Array.isArray(aggregate)) {
    throw policyError('invalid_policy', 'بيانات سياسة الدوام مطلوبة.');
  }
  const attendancePolicy = aggregate.attendancePolicy;
  if (!attendancePolicy || typeof attendancePolicy !== 'object' || Array.isArray(attendancePolicy)) {
    throw policyError('invalid_policy', 'إعدادات الدوام المشتركة مطلوبة.');
  }
  const configuredRemote = aggregate.remoteWorkPolicy || attendancePolicy.remoteWorkPolicy;
  const remoteWorkPolicy = configuredRemote && Object.keys(configuredRemote).length > 0
    ? configuredRemote
    : { schemaVersion: 1, enabled: false };
  const validation = validateRemotePolicy(remoteWorkPolicy);
  if (!validation.valid) {
    const error = policyError('policy_validation_failed', 'راجع الحقول المحددة في سياسة العمل عن بُعد.');
    error.validationErrors = validation.errors;
    throw error;
  }
  return {
    attendancePolicy: { ...attendancePolicy, remoteWorkPolicy },
    remoteWorkPolicy,
  };
}

function refs(db, companyId, actorId, command) {
  const operationId = `${companyId}_${actorId}_${command.operationId}`;
  const draftId = `${companyId}_${command.draftId}`;
  return {
    company: db.collection('companies').doc(companyId),
    operation: db.collection('attendancePolicyOperations').doc(operationId),
    draft: db.collection('attendancePolicyDrafts').doc(draftId),
    head: db.collection('attendancePolicyHeads').doc(companyId),
  };
}

async function executeRemotePolicyCommand({ db, actor, command, now = new Date() }) {
  validateCommand(command);
  requireActor(actor, COMMAND_CAPABILITIES[command.kind]);
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) throw policyError('invalid_server_time');
  const references = refs(db, actor.companyId, actor.uid, command);
  const payloadHash = hash({ kind: command.kind, draftId: command.draftId, expectedVersion: command.expectedVersion, payload: command.payload || {} });
  let result;

  await db.runTransaction(async (transaction) => {
    const capability = COMMAND_CAPABILITIES[command.kind];
    const grantReferences = actor.grantIds[capability].map((id) => db.collection('remoteWorkCapabilityGrants').doc(id));
    const [operationSnapshot, ...grantSnapshots] = await Promise.all([
      transaction.get(references.operation),
      ...grantReferences.map((reference) => transaction.get(reference)),
    ]);
    if (!grantSnapshots.some((snapshot, index) => grantSnapshotAuthorizes({
      snapshot,
      actor,
      capability,
      now,
      expectedVersion: actor.grantVersionsById?.[actor.grantIds[capability][index]],
    }))) throw policyError('not_authorized', 'انتهت صلاحيتك أو تغير نطاقها؛ حدّث الصفحة.');
    if (operationSnapshot.exists) {
      const saved = operationSnapshot.data();
      if (saved.payloadHash !== payloadHash) throw policyError('operation_conflict', 'معرف العملية مستخدم لبيانات مختلفة.');
      result = saved.result;
      return;
    }

    const draftSnapshot = await transaction.get(references.draft);
    const draft = draftSnapshot.exists ? draftSnapshot.data() : null;
    if (command.kind === 'save_policy_draft') {
      if ((draft?.version || 0) !== command.expectedVersion) throw policyError('version_conflict', 'تم تعديل المسودة؛ حدّث البيانات ثم أعد المحاولة.');
      if (draft && draft.state !== 'draft') throw policyError('draft_not_editable');
      const aggregate = normalizedAggregate(command.payload);
      if (command.payload.effectiveFrom !== undefined && !validInstant(command.payload.effectiveFrom)) throw policyError('invalid_effective_date');
      const effectiveFrom = new Date(command.payload.effectiveFrom || draft?.effectiveFrom || now).toISOString();
      const reviewHash = hash({ aggregate, effectiveFrom });
      const version = command.expectedVersion + 1;
      result = { operationId: command.operationId, draftId: command.draftId, status: 'draft_saved', version };
      transaction.set(references.draft, {
        companyId: actor.companyId,
        draftId: command.draftId,
        aggregate,
        effectiveFrom,
        createdBy: draft?.createdBy || actor.uid,
        createdAt: draft?.createdAt || now,
        updatedAt: now,
        approvals: draft?.reviewHash === reviewHash ? (draft.approvals || []) : [],
        state: 'draft',
        version,
        payloadHash: hash(aggregate),
        reviewHash,
      });
    } else if (command.kind === 'revert_policy') {
      if (draft) throw policyError('draft_exists', 'توجد مسودة بهذا المعرف بالفعل.');
      const targetRevisionId = String(command.payload?.targetRevisionId || '');
      if (!SAFE_ID.test(targetRevisionId) || !validInstant(command.payload?.effectiveFrom)) throw policyError('invalid_revert');
      const source = db.collection('attendancePolicyRevisions').doc(`${actor.companyId}_${targetRevisionId}`);
      const sourceSnapshot = await transaction.get(source);
      if (!sourceSnapshot.exists) throw policyError('revision_not_found', 'الإصدار المطلوب استعادته غير موجود.');
      const revision = sourceSnapshot.data();
      const version = 1;
      result = { operationId: command.operationId, draftId: command.draftId, status: 'revert_draft_created', version, targetRevisionId };
      transaction.set(references.draft, {
        companyId: actor.companyId,
        draftId: command.draftId,
        aggregate: revision.aggregate,
        effectiveFrom: command.payload.effectiveFrom,
        createdBy: actor.uid,
        createdAt: now,
        updatedAt: now,
        approvals: [],
        state: 'draft',
        version,
        revertOf: targetRevisionId,
        payloadHash: revision.payloadHash,
        reviewHash: hash({ aggregate: revision.aggregate, effectiveFrom: new Date(command.payload.effectiveFrom).toISOString() }),
      });
    } else {
      if (!draft) throw policyError('draft_not_found', 'المسودة غير موجودة.');
      if (draft.version !== command.expectedVersion) throw policyError('version_conflict', 'تم تعديل المسودة؛ حدّث البيانات ثم أعد المحاولة.');
      if (draft.state !== 'draft') throw policyError('draft_not_editable', 'هذه المسودة لم تعد قابلة للتعديل.');
      if (!validInstant(draft.effectiveFrom) || !draft.reviewHash ||
          draft.reviewHash !== hash({ aggregate: normalizedAggregate(draft.aggregate), effectiveFrom: new Date(draft.effectiveFrom).toISOString() })) {
        throw policyError('policy_review_changed');
      }

      if (command.kind === 'approve_policy') {
        if (command.payload?.decision !== 'approved' || typeof command.payload?.reason !== 'string' || !command.payload.reason.trim()) {
          throw policyError('invalid_approval', 'اكتب سبب المراجعة للموافقة على السياسة.');
        }
        if (actor.uid === draft.createdBy || draft.approvals.some((entry) => entry.actorId === actor.uid)) {
          throw policyError('policy_approver_must_differ', 'يجب أن يراجع السياسة شخص آخر غير منشئ المسودة.');
        }
        const approvals = [...draft.approvals, { actorId: actor.uid, decision: 'approved', reason: command.payload.reason.trim(), createdAt: now,
          reviewHash: draft.reviewHash }];
        result = { operationId: command.operationId, draftId: command.draftId, status: 'approved', version: draft.version + 1 };
        transaction.set(references.draft, { ...draft, approvals, updatedAt: now, version: result.version });
      } else {
        const independentApproval = draft.approvals.find((entry) => entry.decision === 'approved' && entry.actorId !== draft.createdBy && entry.actorId !== actor.uid && entry.reviewHash === draft.reviewHash);
        if (!independentApproval) {
          const selfApproved = draft.approvals.some((entry) => entry.decision === 'approved' && entry.actorId === actor.uid);
          if (selfApproved) throw policyError('policy_publisher_must_differ', 'يجب أن ينشر السياسة شخص آخر غير الموافق عليها.');
          throw policyError('policy_approval_required', 'تحتاج المسودة إلى موافقة مستقلة قبل النشر.');
        }
        if (command.expectedVersion !== draft.version) throw policyError('version_conflict', 'تم تعديل المسودة؛ حدّث البيانات ثم أعد المحاولة.');
        const effectiveFrom = command.payload?.effectiveFrom || draft.effectiveFrom;
        if (!draft.effectiveFrom || Date.parse(effectiveFrom) !== Date.parse(draft.effectiveFrom)) throw policyError('policy_review_changed');
        if (!validInstant(effectiveFrom) || new Date(effectiveFrom).getTime() < now.getTime()) throw policyError('invalid_effective_date', 'حدد موعد نشر حالي أو مستقبلي صحيح.');
        const headSnapshot = await transaction.get(references.head);
        const previousHead = headSnapshot.exists ? headSnapshot.data() : { revision: 0 };
        const revision = previousHead.revision + 1;
        const revisionId = String(revision);
        const revisionRef = db.collection('attendancePolicyRevisions').doc(`${actor.companyId}_${revisionId}`);
        const aggregate = normalizedAggregate(draft.aggregate);
        const effectiveAt = new Date(effectiveFrom);
        const activatesImmediately = effectiveAt.getTime() <= now.getTime();
        const qualification = await readQualifiedProfile({ transaction, db, companyId: actor.companyId,
          policy: draft.aggregate.remoteWorkPolicy, now, requiredAt: effectiveAt });
        const guardRef = db.collection('remoteWorkCalendarGuards').doc(actor.companyId);
        const guardSnapshot = activatesImmediately ? await transaction.get(guardRef) : null;
        const guard = guardSnapshot?.exists ? guardSnapshot.data() : {};
        if (guard.companyId && guard.companyId !== actor.companyId) throw policyError('wrong_company');
        const scheduledRevisions = [...(previousHead.scheduledRevisions || [])];
        if (scheduledRevisions.some((entry) => Date.parse(entry.effectiveFrom) === effectiveAt.getTime()) ||
            (previousHead.activeEffectiveFrom && Date.parse(previousHead.activeEffectiveFrom) === effectiveAt.getTime())) {
          throw policyError('policy_effective_time_conflict');
        }
        if (!activatesImmediately) {
          if (scheduledRevisions.length >= 100) throw policyError('scheduled_revision_limit');
          scheduledRevisions.push({ revision, revisionId, effectiveFrom });
          scheduledRevisions.sort((left, right) => Date.parse(left.effectiveFrom) - Date.parse(right.effectiveFrom));
        }
        result = {
          operationId: command.operationId,
          draftId: command.draftId,
          status: activatesImmediately ? 'published' : 'scheduled',
          version: draft.version + 1,
          revision,
          revisionId,
          effectiveFrom,
        };
        transaction.set(revisionRef, {
          companyId: actor.companyId,
          revision,
          revisionId,
          aggregate,
          ...(qualification ? { qualification } : {}),
          payloadHash: hash(aggregate),
          sourceDraftId: command.draftId,
          approvedBy: independentApproval.actorId,
          publishedBy: actor.uid,
          effectiveFrom,
          state: activatesImmediately ? 'published' : 'scheduled',
          publishedAt: now,
        });
        transaction.set(references.head, {
          companyId: actor.companyId,
          revision,
          revisionId,
          activeRevision: activatesImmediately ? revision : (previousHead.activeRevision || 0),
          scheduledRevisions,
          nextActivationAt: scheduledRevisions.length ? new Date(scheduledRevisions[0].effectiveFrom).toISOString() : null,
          activeEffectiveFrom: activatesImmediately ? effectiveFrom : (previousHead.activeEffectiveFrom || null),
          payloadHash: hash(aggregate),
          effectiveFrom,
          version: (previousHead.version || 0) + 1,
          eligibilityEpoch: (previousHead.eligibilityEpoch || 0) + 1,
          updatedAt: now,
        });
        if (activatesImmediately) {
          transaction.set(references.company, {
            attendancePolicy: aggregate.attendancePolicy,
            attendancePolicyRevision: revision,
            updatedAt: now,
          }, { mergeFields: ['attendancePolicy', 'attendancePolicyRevision', 'updatedAt'] });
          transaction.set(guardRef, {
            ...guard, companyId: actor.companyId, epoch: (guard.epoch || 0) + 1,
            version: (guard.version || 0) + 1, policyRevision: revision, updatedAt: now,
          });
        }
        transaction.set(references.draft, {
          ...draft,
          state: result.status,
          publishedRevision: revision,
          updatedAt: now,
          version: draft.version + 1,
        });
      }
    }
    transaction.set(references.operation, {
      companyId: actor.companyId,
      actorId: actor.uid,
      operationId: command.operationId,
      payloadHash,
      result,
      createdAt: now,
    });
  });
  return result;
}

function grantSnapshotAuthorizes({ snapshot, actor, capability, now, expectedVersion }) {
  if (!snapshot?.exists) return false;
  const grant = snapshot.data() || {};
  if (grant.actorId !== actor.uid || grant.companyId !== actor.companyId ||
      grant.status !== 'active' || grant.revokedAt != null ||
      grant.scopeType !== 'company' || grant.scopeId !== actor.companyId ||
      !Array.isArray(grant.capabilities) || !grant.capabilities.includes(capability)) return false;
  const version = Number(grant.version || 0);
  const expected = Number(expectedVersion);
  if (version !== expected) return false;
  const start = timestampMillis(grant.effectiveFrom);
  const end = timestampMillis(grant.effectiveUntil);
  return (start === null || start <= now.getTime()) && (end === null || now.getTime() < end);
}

function timestampMillis(value) {
  if (value == null) return null;
  if (value?.toDate instanceof Function) return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'string') {
    const milliseconds = Date.parse(value);
    return Number.isNaN(milliseconds) ? NaN : milliseconds;
  }
  return NaN;
}

function validInstant(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value)) && /^\d{4}-\d{2}-\d{2}T/.test(value);
}

module.exports = { executeRemotePolicyCommand, validateCommand, normalizedAggregate, policyError, hashPolicyAggregate: hash };
