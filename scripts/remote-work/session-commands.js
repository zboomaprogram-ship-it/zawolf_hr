'use strict';

const crypto = require('node:crypto');
const { hashRemoteOperation } = require('./operation-identity');

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const SESSION_ACTIONS = new Set(['save_plan', 'submit_update', 'save_summary']);

function sessionError(code, messageAr = 'تعذر تحديث جلسة العمل عن بعد.') {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

function requireSessionActor(actor) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw sessionError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
}

async function executeRemoteSessionCommand({ db, admin, actor, command, now = new Date() }) {
  requireSessionActor(actor);
  if (!command || !SESSION_ACTIONS.has(command.kind)) {
    throw sessionError('invalid_command', 'نوع أمر الجلسة غير صالح.');
  }

  const { operationId, kind, date, sessionId, payload = {} } = command;
  if (!SAFE_ID.test(String(operationId || ''))) {
    throw sessionError('invalid_command', 'معرف العملية غير صالح.');
  }
  if (!SAFE_ID.test(String(sessionId || ''))) {
    throw sessionError('invalid_command', 'معرف جلسة العمل عن بعد غير صالح.');
  }
  if (!date || typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw sessionError('invalid_date', 'تاريخ الوردية غير صالح.');
  }

  const companyId = actor.companyId;
  const actorId = actor.uid;
  const sessionDocId = `${companyId}_${sessionId}`;
  const sessionRef = db.collection('remoteWorkSessions').doc(sessionDocId);

  // Dynamic limits resolved from policy with safe defaults per spec FR-12
  const policyLimits = command.policyLimits || command.resolvedPolicy?.sessionLimits || {};
  const minGoals = Number.isInteger(policyLimits.minGoals) ? policyLimits.minGoals : 1;
  const maxGoals = Number.isInteger(policyLimits.maxGoals) ? policyLimits.maxGoals : 10;
  const goalTextLimit = Number.isInteger(policyLimits.goalTextLimit) ? policyLimits.goalTextLimit : 500;
  const updateTextLimit = Number.isInteger(policyLimits.updateTextLimit) ? policyLimits.updateTextLimit : 1000;
  const summaryTextLimit = Number.isInteger(policyLimits.summaryTextLimit) ? policyLimits.summaryTextLimit : 4000;

  // Validate specific command payloads against resolved limits
  if (kind === 'save_plan') {
    const goals = payload.goals;
    if (!Array.isArray(goals) || goals.length < minGoals || goals.length > maxGoals) {
      throw sessionError('invalid_plan', `يجب إدخال أهداف خطة العمل اليومية بشكل صحيح (${minGoals} إلى ${maxGoals} أهداف).`);
    }
    if (goals.some(g => typeof g !== 'string' || g.trim().length === 0 || g.length > goalTextLimit)) {
      throw sessionError('invalid_plan', `نص الهدف يجب ألا يتجاوز ${goalTextLimit} حرف.`);
    }
  } else if (kind === 'submit_update') {
    const text = String(payload.updateText || '').trim();
    if (text.length === 0 || text.length > updateTextLimit) {
      throw sessionError('invalid_update', `يجب إدخال تفاصيل التحديث الدوري بما لا يتجاوز ${updateTextLimit} حرف.`);
    }

    let targetCheckpoint = null;
    if (payload.checkpointId || Number.isInteger(payload.slotIndex)) {
      let checkpoints = command.checkpoints || command.resolvedPolicy?.schedule?.checkpoints;
      if (!Array.isArray(checkpoints)) {
        const compSnap = await db.collection('companies').doc(companyId).get();
        const compData = compSnap.exists ? (compSnap.data() || {}) : {};
        checkpoints = compData.attendancePolicy?.remoteWorkPolicy?.schedule?.checkpoints || [];
      }
      if (Array.isArray(checkpoints)) {
        targetCheckpoint = checkpoints.find((c) => c.id === payload.checkpointId) ||
          (Number.isInteger(payload.slotIndex) && payload.slotIndex > 0 ? checkpoints[payload.slotIndex - 1] : null);
      }
    }

    if (targetCheckpoint && targetCheckpoint.dueTime) {
      const parts = String(targetCheckpoint.dueTime).split(':').map(Number);
      if (parts.length >= 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
        const dueMin = parts[0] * 60 + parts[1];
        const graceMin = Number(targetCheckpoint.graceMinutes ?? 15);
        const deadlineMin = dueMin + graceMin;

        const cairoDate = new Intl.DateTimeFormat('en-US', {
          timeZone: 'Africa/Cairo',
          hour: 'numeric',
          minute: 'numeric',
          hourCycle: 'h23',
        }).formatToParts(now);
        const currentHour = Number(cairoDate.find((p) => p.type === 'hour')?.value ?? 0);
        const currentMinute = Number(cairoDate.find((p) => p.type === 'minute')?.value ?? 0);
        const nowMin = currentHour * 60 + currentMinute;

        if (nowMin > deadlineMin) {
          throw sessionError(
            'checkpoint_window_expired',
            `انتهت فترة السماح المحددة لنقطة المتابعة (${targetCheckpoint.label || targetCheckpoint.dueTime}) ولا يمكن تسجيلها بعد انتهاء الوقت.`
          );
        }
      }
    }
  } else if (kind === 'save_summary') {
    const summary = String(payload.summaryText || '').trim();
    if (summary.length === 0 || summary.length > summaryTextLimit) {
      throw sessionError('invalid_summary', `يجب إدخال ملخص نهاية اليوم بما لا يتجاوز ${summaryTextLimit} حرف.`);
    }
  }

  // Calculate canonical payload hash
  const payloadHash = hashRemoteOperation({
    operationId,
    kind,
    date,
    sessionId,
    expectedVersion: command.expectedVersion,
    payload,
  });

  const operationRef = db.collection('remoteWorkOperations').doc(`${companyId}_${actorId}_${operationId}`);

  return db.runTransaction(async (tx) => {
    // Check operation inside transaction for idempotency
    const opSnap = await tx.get(operationRef);
    if (opSnap.exists) {
      const data = opSnap.data() || {};
      if (data.payloadHash !== payloadHash) {
        throw sessionError('operation_conflict', 'معرف العملية مسجل لبيانات أخرى.');
      }
      return {
        operationId,
        status: 'already_recorded',
        sessionId,
        version: data.version || 1,
        serverTime: data.serverTime || now.toISOString(),
      };
    }

    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) {
      throw sessionError('session_not_found', 'جلسة العمل عن بعد غير موجودة.');
    }

    const sessionData = sessionSnap.data() || {};
    if (sessionData.userId !== actorId) {
      throw sessionError('not_authorized', 'لا يمكنك تعديل جلسة عمل خاصة بموظف آخر.');
    }

    const currentVersion = sessionData.version || 1;
    if (command.expectedVersion !== undefined && command.expectedVersion !== currentVersion) {
      throw sessionError('version_conflict', 'تم تعديل الجلسة بواسطة عملية أخرى؛ حدّث البيانات وأعد المحاولة.');
    }

    const nextVersion = currentVersion + 1;
    const sessionUpdates = {
      version: nextVersion,
      updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    };

    const eventId = `${sessionId}_${kind}_${Date.now()}`;
    const eventData = {
      eventId,
      sessionId,
      companyId,
      actorId,
      kind,
      payload,
      version: nextVersion,
      createdAt: now.toISOString(),
    };

    if (kind === 'save_plan') {
      sessionUpdates.plan = payload.goals;
      sessionUpdates.planSubmittedAt = now.toISOString();
    } else if (kind === 'submit_update') {
      const existingUpdates = Array.isArray(sessionData.updates) ? sessionData.updates : [];
      sessionUpdates.updates = [
        ...existingUpdates,
        {
          slotIndex: payload.slotIndex ?? (existingUpdates.length + 1),
          checkpointId: payload.checkpointId || null,
          text: payload.updateText.trim(),
          submittedAt: now.toISOString(),
        },
      ];
    } else if (kind === 'save_summary') {
      sessionUpdates.summary = payload.summaryText.trim();
      sessionUpdates.summarySubmittedAt = now.toISOString();
    }

    tx.set(sessionRef, sessionUpdates, { merge: true });

    // Store immutable event in remoteWorkSessionEvents collection
    const eventRef = db.collection('remoteWorkSessionEvents').doc(eventId);
    tx.set(eventRef, eventData);

    // Record idempotent receipt
    tx.set(operationRef, {
      operationId,
      actorId,
      companyId,
      kind,
      date,
      sessionId,
      payloadHash,
      version: nextVersion,
      status: 'recorded',
      serverTime: now.toISOString(),
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    // Write audit event
    const auditRef = db.collection('remoteWorkAudit').doc();
    tx.set(auditRef, {
      eventId: auditRef.id,
      companyId,
      actorId,
      action: `remote_session_${kind}`,
      targetId: sessionId,
      version: nextVersion,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    return {
      operationId,
      status: 'recorded',
      sessionId,
      version: nextVersion,
      serverTime: now.toISOString(),
    };
  });
}

module.exports = {
  executeRemoteSessionCommand,
  sessionError,
};
