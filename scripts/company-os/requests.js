'use strict';

const crypto = require('node:crypto');
const { classifyRequest, materializeApprovalPlan } = require('./approval-policy');
const { executeOperation } = require('./operation-gateway');
const { requestNotificationOutbox } = require('./notifications');
const { validateAttachmentReferences } = require('./security');

const REQUEST_COLLECTION = 'administrativeRequests';

function requestIdFor(operationId) {
  return `osr_${crypto.createHash('sha256').update(operationId).digest('hex').slice(0, 24)}`;
}

function requiredText(value, field, max = 2000) {
  const text = String(value || '').trim();
  if (!text || text.length > max) {
    const error = new Error(`Invalid ${field}`);
    error.code = 'invalid_input';
    throw error;
  }
  return text;
}

function executionDate(value) {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) {
    const error = new Error('Invalid execution date');
    error.code = 'invalid_input';
    throw error;
  }
  return date;
}

function specialistRoleForRequest(requestType) {
  return new Set(['access', 'it_access', 'asset_purchase', 'repair_maintenance', 'software_license']).has(requestType)
    ? 'it_manager'
    : null;
}

function legacyStatus(stage, terminalStatus = null) {
  if (terminalStatus) return terminalStatus;
  return {
    manager: 'pending_manager',
    specialist: 'pending_specialist',
    finance: 'pending_finance',
    owner: 'pending_ceo',
    payment: 'pending_payment',
    closure: 'pending_closure',
  }[stage?.type] || 'pending_manager';
}

function publicRequest(request) {
  if (!request) return null;
  const { privateNotes, internalMetadata, ...safe } = request;
  return safe;
}

function validateCreateInput(input, actor) {
  const classification = classifyRequest(input.requestType);
  const amount = input.amount == null || input.amount === '' ? null : Number(input.amount);
  if (classification.costBearing && (!Number.isFinite(amount) || amount < 0)) {
    const error = new Error('Invalid amount');
    error.code = 'invalid_input';
    throw error;
  }
  const managerUid = String(actor.managerIds?.[0] || '').trim();
  const specialistRole = specialistRoleForRequest(classification.type);
  if (!managerUid && !specialistRole) {
    const error = new Error('Manager unavailable');
    error.code = 'access_denied';
    throw error;
  }
  return {
    requestType: classification.type,
    costBearing: classification.costBearing,
    businessReason: requiredText(input.businessReason || input.reason, 'businessReason'),
    executionDate: executionDate(input.executionDate),
    amount,
    currency: classification.costBearing ? String(input.currency || 'EGP').trim().slice(0, 8) : null,
    managerUid,
    specialistRole,
    attachments: validateAttachmentReferences(input),
  };
}

function canActOnStage(actor, stage, request = null) {
  if (!actor?.active || !stage || stage.status !== 'pending') return false;
  if (stage.assigneeUid) return stage.assigneeUid === actor.uid;
  if (stage.type === 'closure') {
    // Closure of an IT ticket remains an IT responsibility.  Generic HR/admin
    // accounts cannot bypass the assigned manager/IT route.
    if (request?.specialistRole === 'it_manager') {
      return stage.role === actor.role || actor.role === 'super_admin';
    }
    return stage.role === actor.role || ['admin', 'super_admin', 'hr_admin'].includes(actor.role);
  }
  return stage.role === actor.role;
}

function requestOperation({ store, actor, operationId, requestId, expectedVersion, operationType, payload, mutation, now = new Date() }) {
  return executeOperation({
    store,
    actor,
    operationId,
    targetId: requestId,
    operationType,
    expectedVersion,
    payload,
    now,
    currentVersion: async (tx) => (await tx.getRequest(requestId))?.version,
    mutate: async (tx) => {
      const request = await tx.getRequest(requestId);
      if (!request) {
        const error = new Error('Request missing');
        error.code = 'not_found';
        throw error;
      }
      return mutation(tx, request);
    },
  });
}

async function createRequest({ store, actor, operationId, input, ownerPolicy, now = new Date() }) {
  const payload = validateCreateInput(input, actor);
  const requestId = requestIdFor(operationId);
  const plan = materializeApprovalPlan({
    requestId,
    requestType: payload.requestType,
    managerUid: payload.managerUid,
    specialistRole: payload.specialistRole,
    ownerPolicy,
    createdAt: now,
  });
  return executeOperation({
    store,
    actor,
    operationId,
    targetId: requestId,
    operationType: 'request_create',
    payload: { ...payload, executionDate: payload.executionDate.toISOString() },
    now,
    mutate: async (tx) => {
      const firstStage = plan.stages[0];
      await tx.createRequest({
        id: requestId,
        userId: actor.uid,
        requesterUid: actor.uid,
        employeeId: actor.employeeId,
        employeeName: actor.displayName,
        department: actor.department,
        category: 'company_os',
        categoryLabel: 'طلب تشغيلي',
        notes: payload.businessReason,
        businessReason: payload.businessReason,
        requestType: payload.requestType,
        specialistRole: payload.specialistRole,
        costBearing: payload.costBearing,
        amount: payload.amount,
        currency: payload.currency,
        executionDate: payload.executionDate,
        submittedAt: now,
        status: legacyStatus(firstStage),
        operationalStatus: 'pending',
        managerId: payload.managerUid || null,
        managerIds: payload.managerUid ? [payload.managerUid] : [],
        attachments: payload.attachments,
        approvalPolicyVersion: plan.policyVersion,
        approvalPlan: plan,
        currentStageIndex: 0,
        approvalHistory: [{ stage: 'submitted', decision: 'submitted', actorUid: actor.uid, at: now }],
        version: 1,
        updatedAt: now,
      });
      if (tx.putNotification) await tx.putNotification(requestNotificationOutbox({
        operationId,
        requestId,
        requesterUid: actor.uid,
        stage: firstStage,
      }));
      return { resourceId: requestId, version: 1 };
    },
  });
}

async function decideRequest({ store, actor, operationId, requestId, expectedVersion, approved, reason, now = new Date() }) {
  const decision = approved === true ? 'approved' : 'rejected';
  const safeReason = requiredText(reason, 'reason', 1000);
  return requestOperation({
    store,
    actor,
    operationId,
    requestId,
    expectedVersion,
    operationType: 'request_decide',
    payload: { decision, reason: safeReason },
    now,
    mutation: async (tx, request) => {
      if (['approved', 'rejected', 'closed'].includes(request.operationalStatus)) {
        const error = new Error('Request already completed');
        error.code = 'conflict';
        throw error;
      }
      const stages = (request.approvalPlan?.stages || []).map((stage) => ({ ...stage }));
      const index = Number(request.currentStageIndex || 0);
      const stage = stages[index];
      if (!canActOnStage(actor, stage, request)) {
        const error = new Error('Wrong approval stage');
        error.code = 'access_denied';
        throw error;
      }
      stage.status = decision;
      stage.decidedAt = now;
      stage.decidedBy = actor.uid;
      stage.reason = safeReason;
      const version = Number(request.version || 0) + 1;
      const isRejected = decision === 'rejected';
      const nextIndex = isRejected ? index : index + 1;
      const completed = !isRejected && nextIndex >= stages.length;
      const operationalStatus = isRejected ? 'rejected' : completed ? 'closed' : 'pending';
      await tx.updateRequest(requestId, {
        approvalPlan: { ...request.approvalPlan, stages },
        currentStageIndex: nextIndex,
        operationalStatus,
        status: legacyStatus(stages[nextIndex], isRejected ? 'rejected' : completed ? 'approved' : null),
        approvalHistory: [...(request.approvalHistory || []), {
          stage: stage.type,
          decision,
          reason: safeReason,
          actorUid: actor.uid,
          at: now,
        }],
        version,
        updatedAt: now,
      });
      if (tx.putNotification) {
        const nextStage = stages[nextIndex];
        await tx.putNotification(requestNotificationOutbox({
          operationId,
          requestId,
          requesterUid: request.requesterUid || request.userId,
          stage: nextStage || { assigneeUid: request.requesterUid || request.userId },
          status: isRejected ? 'rejected' : completed ? 'closed' : 'pending',
        }));
      }
      return { resourceId: requestId, version };
    },
  });
}

function completeStage({ store, actor, operationId, requestId, expectedVersion, stageType, details = {}, now = new Date() }) {
  return requestOperation({
    store,
    actor,
    operationId,
    requestId,
    expectedVersion,
    operationType: `request_${stageType}_complete`,
    payload: details,
    now,
    mutation: async (tx, request) => {
      const stage = request.approvalPlan?.stages?.[Number(request.currentStageIndex || 0)];
      if (stage?.type !== stageType || !canActOnStage(actor, stage, request)) {
        const error = new Error('Wrong completion stage');
        error.code = 'access_denied';
        throw error;
      }
      return decideRequestMutation({ tx, request, requestId, actor, reason: details.reference || details.note || 'تم التنفيذ', now });
    },
  });
}

async function decideRequestMutation({ tx, request, requestId, actor, reason, now }) {
  const stages = (request.approvalPlan?.stages || []).map((stage) => ({ ...stage }));
  const index = Number(request.currentStageIndex || 0);
  const stage = stages[index];
  stage.status = 'approved';
  stage.decidedAt = now;
  stage.decidedBy = actor.uid;
  stage.reason = reason;
  const nextIndex = index + 1;
  const completed = nextIndex >= stages.length;
  const version = Number(request.version || 0) + 1;
  await tx.updateRequest(requestId, {
    approvalPlan: { ...request.approvalPlan, stages },
    currentStageIndex: nextIndex,
    operationalStatus: completed ? 'closed' : 'pending',
    status: legacyStatus(stages[nextIndex], completed ? 'approved' : null),
    approvalHistory: [...(request.approvalHistory || []), { stage: stage.type, decision: 'approved', reason, actorUid: actor.uid, at: now }],
    version,
    updatedAt: now,
  });
  if (tx.putNotification) await tx.putNotification(requestNotificationOutbox({
    operationId: `stage:${requestId}:${version}`,
    requestId,
    requesterUid: request.requesterUid || request.userId,
    stage: stages[nextIndex] || { assigneeUid: request.requesterUid || request.userId },
    status: completed ? 'closed' : 'pending',
  }));
  return { resourceId: requestId, version };
}

function createFirestoreRequestStore(db) {
  return {
    transact(work) {
      return db.runTransaction(async (transaction) => work({
        async getReceipt(id) {
          const snapshot = await transaction.get(db.collection('companyOsOperationReceipts').doc(id));
          return snapshot.exists ? snapshot.data() : null;
        },
        async putReceipt(id, value) { transaction.create(db.collection('companyOsOperationReceipts').doc(id), value); },
        async putAudit(id, value) { transaction.create(db.collection('companyOsAuditEvents').doc(id), value); },
        async getRequest(id) {
          const snapshot = await transaction.get(db.collection(REQUEST_COLLECTION).doc(id));
          return snapshot.exists ? { id: snapshot.id, ...snapshot.data() } : null;
        },
        async createRequest(value) { transaction.create(db.collection(REQUEST_COLLECTION).doc(value.id), value); },
        async updateRequest(id, value) { transaction.update(db.collection(REQUEST_COLLECTION).doc(id), value); },
        async putNotification(value) { transaction.create(db.collection('companyOsNotificationOutbox').doc(value.id), value); },
      }));
    },
  };
}

module.exports = {
  REQUEST_COLLECTION,
  requestIdFor,
  specialistRoleForRequest,
  legacyStatus,
  publicRequest,
  validateCreateInput,
  canActOnStage,
  createRequest,
  decideRequest,
  completeStage,
  createFirestoreRequestStore,
};
