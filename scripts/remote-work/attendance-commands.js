'use strict';

const crypto = require('node:crypto');
const { hashRemoteOperation } = require('./operation-identity');
const { enforceDayMode } = require('./day-mode-guard');
const { consumeVerifiedChallenge } = require('./challenges');

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function attendanceError(code, messageAr = 'تعذر تسجيل الحضور عن بعد.') {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

const CAIRO_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Africa/Cairo',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

function cairoDateKey(d = new Date()) {
  return CAIRO_FORMATTER.format(d);
}

function requireRemoteActor(actor) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw attendanceError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
}

async function executeRemoteAttendance({ db, admin, actor, command, now = new Date() }) {
  requireRemoteActor(actor);
  if (!command || !['check_in', 'check_out'].includes(command.kind)) {
    throw attendanceError('invalid_command', 'نوع أمر الحضور غير صالح.');
  }

  const { operationId, kind, payload = {}, proof } = command;
  if (!SAFE_ID.test(String(operationId || ''))) {
    throw attendanceError('invalid_command', 'معرف العملية غير صالح.');
  }

  const serverDate = cairoDateKey(now);
  let date = command.date;
  if (kind === 'check_in') {
    if (date && date !== serverDate) {
      throw attendanceError('invalid_date', 'لا يمكن تسجيل الحضور عن بعد لتاريخ غير تاريخ اليوم الفعلي.');
    }
    date = serverDate;
  } else {
    date = date || serverDate;
  }

  if (!date || typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw attendanceError('invalid_date', 'تاريخ الوردية غير صالح.');
  }

  const companyId = actor.companyId;
  const actorId = actor.uid;
  const attendanceId = `${actorId}_${date}`;
  const sessionId = command.sessionId || `${actorId}_${date}`;

  // Operation receipt lookup is performed inside the transaction for atomicity.
  const operationRef = db.collection('remoteWorkOperations').doc(`${companyId}_${actorId}_${operationId}`);

  // Calculate canonical payload hash
  const payloadHash = hashRemoteOperation({
    operationId,
    kind,
    date,
    sessionId: kind === 'check_out' ? sessionId : null,
    expectedVersion: command.expectedVersion,
    payload,
  });

  const attendanceRef = db.collection('attendance').doc(attendanceId);
  const sessionRef = db.collection('remoteWorkSessions').doc(`${companyId}_${sessionId}`);

  const receipt = await db.runTransaction(async (tx) => {
    // Check operation inside transaction to prevent race conditions
    const opSnap = await tx.get(operationRef);
    if (opSnap.exists) {
      const data = opSnap.data() || {};
      if (data.payloadHash !== payloadHash) {
        throw attendanceError('operation_conflict', 'معرف العملية مسجل لبيانات أخرى.');
      }
      return {
        operationId,
        status: 'already_recorded',
        attendanceId: data.attendanceId || attendanceId,
        sessionId: data.sessionId || sessionId,
        mode: data.mode || 'remote_web',
        version: data.version || 1,
        serverTime: data.serverTime || now.toISOString(),
      };
    }

    // Enforce day-mode lock
    const modeDecision = await enforceDayMode({
      transaction: tx,
      db,
      actorId,
      date,
      requestedMode: 'remote_web',
      evidence: { verifiedProof: proof },
    });

    if (proof) {
      await consumeVerifiedChallenge({
        db,
        transaction: tx,
        actor,
        command: { ...command, date, payloadHash },
        proof,
        now,
      });
    }

    const currentAtt = await tx.get(attendanceRef);
    let nextVersion = 1;

    if (kind === 'check_in') {
      if (currentAtt.exists && currentAtt.data()?.checkInTime) {
        throw attendanceError('already_checked_in', 'تم تسجيل الحضور لهذا اليوم مسبقاً.');
      }
      nextVersion = currentAtt.exists ? ((currentAtt.data()?.version || 1) + 1) : 1;

      const policySnapshot = command.policySnapshot || (command.resolvedPolicy ? {
        policyVersion: command.resolvedPolicy.revision || 1,
        policyRevisionId: command.resolvedPolicy.revisionId || '1',
        policyHash: command.resolvedPolicy.hash || null,
      } : null);

      tx.set(attendanceRef, {
        userId: actorId,
        date,
        checkInTime: admin?.firestore?.FieldValue?.serverTimestamp ? admin.firestore.FieldValue.serverTimestamp() : now,
        isRemote: true,
        attendanceMode: 'remote_web',
        companyId,
        remoteSessionId: sessionId,
        remoteCredentialId: proof?.credentialId || null,
        policySnapshot,
        status: 'present',
        version: nextVersion,
        updatedAt: admin?.firestore?.FieldValue?.serverTimestamp ? admin.firestore.FieldValue.serverTimestamp() : now,
      }, { merge: true });

      tx.set(sessionRef, {
        sessionId,
        companyId,
        userId: actorId,
        date,
        attendanceId,
        status: 'active',
        policySnapshot,
        version: nextVersion,
        createdAt: admin?.firestore?.FieldValue?.serverTimestamp ? admin.firestore.FieldValue.serverTimestamp() : now,
      }, { merge: true });
    } else if (kind === 'check_out') {
      if (!currentAtt.exists || !currentAtt.data()?.checkInTime) {
        throw attendanceError('check_in_required', 'يجب تسجيل الحضور أولاً قبل تسجيل الانصراف.');
      }
      nextVersion = (currentAtt.data()?.version || 1) + 1;

      tx.set(attendanceRef, {
        checkOutTime: admin?.firestore?.FieldValue?.serverTimestamp() || now,
        version: nextVersion,
        updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
      }, { merge: true });

      tx.set(sessionRef, {
        status: 'completed',
        version: nextVersion,
        completedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
      }, { merge: true });
    }

    // Write operation receipt
    tx.set(operationRef, {
      operationId,
      actorId,
      companyId,
      kind,
      date,
      payloadHash,
      attendanceId,
      sessionId,
      mode: 'remote_web',
      version: nextVersion,
      status: 'recorded',
      serverTime: now.toISOString(),
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    // Write audit log
    const auditRef = db.collection('remoteWorkAudit').doc();
    tx.set(auditRef, {
      eventId: auditRef.id,
      companyId,
      actorId,
      action: kind === 'check_in' ? 'remote_check_in' : 'remote_check_out',
      targetId: attendanceId,
      sessionId,
      version: nextVersion,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    return {
      operationId,
      status: 'recorded',
      attendanceId,
      sessionId,
      mode: 'remote_web',
      version: nextVersion,
      serverTime: now.toISOString(),
    };
  });

  return receipt;
}

module.exports = {
  executeRemoteAttendance,
  attendanceError,
};
