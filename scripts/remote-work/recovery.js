'use strict';

const crypto = require('node:crypto');

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function recoveryError(code, messageAr = 'تعذر تصحيح سجل الحضور عن بعد.') {
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

function requireRecoveryActor(actor) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw recoveryError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
  const caps = Array.isArray(actor.capabilities) ? actor.capabilities : [];
  if (!caps.includes('hr_admin') && !caps.includes('attendance_correction')) {
    throw recoveryError('not_authorized', 'صلاحية تصحيح سجلات الحضور مخصصة لمسؤولي الموارد البشرية.');
  }
}

async function correctRemoteDay({ db, admin, actor, command, now = new Date() }) {
  requireRecoveryActor(actor);
  if (!command || command.kind !== 'correct_day') {
    throw recoveryError('invalid_command', 'نوع أمر التصحيح غير صالح.');
  }

  const { operationId, payload = {} } = command;
  if (!SAFE_ID.test(String(operationId || ''))) {
    throw recoveryError('invalid_command', 'معرف العملية غير صالح.');
  }

  const { attendanceId, checkInTime, checkOutTime, correctionReason } = payload;
  if (!SAFE_ID.test(String(attendanceId || '')) || !correctionReason || typeof correctionReason !== 'string') {
    throw recoveryError('invalid_payload', 'معرف الحضور وسبب التصحيح إلزاميان.');
  }

  const companyId = actor.companyId;
  const operationRef = db.collection('remoteWorkOperations').doc(`${companyId}_${actor.uid}_${operationId}`);
  const attendanceRef = db.collection('attendance').doc(attendanceId);

  const payloadHash = hash(payload);

  return db.runTransaction(async (tx) => {
    const opSnap = await tx.get(operationRef);
    if (opSnap.exists) {
      const data = opSnap.data() || {};
      if (data.payloadHash !== payloadHash) {
        throw recoveryError('operation_conflict', 'معرف العملية مسجل لبيانات أخرى.');
      }
      return {
        operationId,
        status: 'already_recorded',
        attendanceId: data.attendanceId || attendanceId,
        version: data.version || 1,
        serverTime: data.serverTime || now.toISOString(),
      };
    }

    const attSnap = await tx.get(attendanceRef);
    if (!attSnap.exists) {
      throw recoveryError('attendance_not_found', 'سجل الحضور المراد تصحيحه غير موجود.');
    }

    const attData = attSnap.data() || {};
    if (attData.companyId && attData.companyId !== companyId) {
      throw recoveryError('forbidden_scope', 'لا يمكن تصحيح سجل حضور تابع لشركة أخرى.');
    }

    if (command.expectedVersion !== undefined && command.expectedVersion !== null) {
      const currentVer = attData.version || 1;
      if (currentVer !== Number(command.expectedVersion)) {
        throw recoveryError('version_conflict', 'تم تعديل سجل الحضور بواسطة عملية أخرى بالتزامن.');
      }
    }

    const nextVersion = (attData.version || 1) + 1;

    const updates = {
      version: nextVersion,
      manuallyCorrected: true,
      correctedBy: actor.uid,
      correctionReason: correctionReason.trim(),
      correctedAt: now.toISOString(),
      updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    };

    if (checkInTime) updates.checkInTime = checkInTime;
    if (checkOutTime) updates.checkOutTime = checkOutTime;

    tx.set(attendanceRef, updates, { merge: true });

    // Record idempotent receipt
    tx.set(operationRef, {
      operationId,
      actorId: actor.uid,
      companyId,
      kind: 'correct_day',
      payloadHash,
      attendanceId,
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
      actorId: actor.uid,
      action: 'correct_remote_day',
      targetId: attendanceId,
      reason: correctionReason.trim(),
      version: nextVersion,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    return {
      operationId,
      status: 'recorded',
      attendanceId,
      version: nextVersion,
      serverTime: now.toISOString(),
    };
  });
}

module.exports = {
  correctRemoteDay,
  recoveryError,
};
