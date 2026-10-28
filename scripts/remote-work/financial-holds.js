'use strict';

const crypto = require('node:crypto');

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function holdError(code, messageAr = 'تعذر معالجة التعليق المالي أو الحادثة التقنية.') {
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

function requireHoldActor(actor, requiredRole) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw holdError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
  const caps = Array.isArray(actor.capabilities) ? actor.capabilities : [];
  if (requiredRole === 'it' && !caps.includes('it_admin') && !caps.includes('declare_incident')) {
    throw holdError('not_authorized', 'صلاحية إعلان الحادثة التقنية مخصصة لمسؤولي تقنية المعلومات.');
  }
  if (requiredRole === 'hr' && !caps.includes('hr_admin') && !caps.includes('payroll_manager') && !caps.includes('resolve_hold')) {
    throw holdError('not_authorized', 'صلاحية فك التعليق المالي مخصصة لمسؤولي الموارد البشرية والرواتب.');
  }
}

async function declareRemoteIncident({ db, admin, actor, command, now = new Date() }) {
  requireHoldActor(actor, 'it');
  if (!command || command.kind !== 'declare_incident') {
    throw holdError('invalid_command', 'نوع أمر الحادثة غير صالح.');
  }

  const { operationId, payload = {} } = command;
  if (!SAFE_ID.test(String(operationId || ''))) {
    throw holdError('invalid_command', 'معرف العملية غير صالح.');
  }

  const { startDate, endDate, reason, affectedEmployees = [] } = payload;
  if (!startDate || !endDate || !reason || typeof reason !== 'string' || reason.trim().length === 0) {
    throw holdError('invalid_incident_payload', 'بيانات الحادثة التقنية غير مكتملة (تاريخ البداية والنهاية والسبب إلزامي).');
  }

  const startMs = Date.parse(startDate);
  const endMs = Date.parse(endDate);
  if (isNaN(startMs) || isNaN(endMs) || endMs < startMs) {
    throw holdError('invalid_date_range', 'نطاق التواريخ غير صالح.');
  }
  const diffDays = Math.ceil((endMs - startMs) / (1000 * 60 * 60 * 24)) + 1;
  if (diffDays > 7) {
    throw holdError('incident_range_exceeded', 'لا يمكن إعلان حادثة تقنية تتجاوز 7 أيام كحد أقصى.');
  }
  if (!Array.isArray(affectedEmployees) || affectedEmployees.length > 500) {
    throw holdError('invalid_incident_payload', 'قائمة الموظفين المتأثرين غير صالحة أو تتجاوز الحد الأقصى المسموح.');
  }

  const companyId = actor.companyId;
  const operationRef = db.collection('remoteWorkOperations').doc(`${companyId}_${actor.uid}_${operationId}`);
  const incidentId = payload.incidentId && SAFE_ID.test(payload.incidentId)
    ? payload.incidentId
    : `inc_${Date.now()}_${actor.uid}`;
  const incidentRef = db.collection('remoteWorkIncidents').doc(incidentId);

  const payloadHash = hash(payload);

  return db.runTransaction(async (tx) => {
    const opSnap = await tx.get(operationRef);
    if (opSnap.exists) {
      const data = opSnap.data() || {};
      if (data.payloadHash !== payloadHash) {
        throw holdError('operation_conflict', 'معرف العملية مسجل لبيانات أخرى.');
      }
      return {
        operationId,
        status: 'already_recorded',
        incidentId: data.incidentId || incidentId,
        version: data.version || 1,
        serverTime: data.serverTime || now.toISOString(),
      };
    }

    const incidentData = {
      incidentId,
      companyId,
      declaredBy: actor.uid,
      startDate,
      endDate,
      reason: reason.trim(),
      affectedEmployees,
      status: 'active',
      version: 1,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    };

    tx.set(incidentRef, incidentData);

    // Write coverage records for each affected employee on start date
    for (const empId of affectedEmployees) {
      if (SAFE_ID.test(empId)) {
        const coverageId = `${incidentId}_${empId}_${startDate}`;
        const coverageRef = db.collection('remoteWorkIncidentCoverage').doc(coverageId);
        tx.set(coverageRef, {
          coverageId,
          incidentId,
          employeeId: empId,
          companyId,
          date: startDate,
          status: 'covered',
          createdAt: now.toISOString(),
        });

        // Set financial hold on attendance if exists
        const attId = `${empId}_${startDate}`;
        const holdRef = db.collection('remoteWorkFinancialHolds').doc(attId);
        tx.set(holdRef, {
          attendanceId: attId,
          companyId,
          employeeId: empId,
          incidentId,
          open: true,
          reason: reason.trim(),
          createdAt: now.toISOString(),
        }, { merge: true });
      }
    }

    // Record idempotent receipt
    tx.set(operationRef, {
      operationId,
      actorId: actor.uid,
      companyId,
      kind: 'declare_incident',
      payloadHash,
      incidentId,
      version: 1,
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
      action: 'declare_remote_incident',
      targetId: incidentId,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    return {
      operationId,
      status: 'recorded',
      incidentId,
      version: 1,
      serverTime: now.toISOString(),
    };
  });
}

async function resolveRemoteFinancialHold({ db, admin, actor, command, now = new Date() }) {
  requireHoldActor(actor, 'hr');
  if (!command || command.kind !== 'resolve_hold') {
    throw holdError('invalid_command', 'نوع أمر فك التعليق غير صالح.');
  }

  const { operationId, payload = {} } = command;
  if (!SAFE_ID.test(String(operationId || ''))) {
    throw holdError('invalid_command', 'معرف العملية غير صالح.');
  }

  const { attendanceId, resolutionReason } = payload;
  if (!attendanceId || !resolutionReason || typeof resolutionReason !== 'string') {
    throw holdError('invalid_payload', 'معرف الحضور وسبب فك التعليق المالي إلزاميان.');
  }

  const companyId = actor.companyId;
  const operationRef = db.collection('remoteWorkOperations').doc(`${companyId}_${actor.uid}_${operationId}`);
  const holdRef = db.collection('remoteWorkFinancialHolds').doc(attendanceId);

  const payloadHash = hash(payload);

  return db.runTransaction(async (tx) => {
    const opSnap = await tx.get(operationRef);
    if (opSnap.exists) {
      const data = opSnap.data() || {};
      if (data.payloadHash !== payloadHash) {
        throw holdError('operation_conflict', 'معرف العملية مسجل لبيانات أخرى.');
      }
      return {
        operationId,
        status: 'already_recorded',
        attendanceId: data.attendanceId || attendanceId,
        version: data.version || 1,
        serverTime: data.serverTime || now.toISOString(),
      };
    }

    const holdSnap = await tx.get(holdRef);
    if (!holdSnap.exists) {
      throw holdError('hold_not_found', 'سجل التعليق المالي غير موجود.');
    }
    const holdData = holdSnap.data() || {};
    if (holdData.companyId && holdData.companyId !== companyId) {
      throw holdError('forbidden_scope', 'لا يمكن فك تعليق مالي تابع لشركة أخرى.');
    }

    const nextVersion = ((holdData.version || 1) + 1);

    tx.set(holdRef, {
      open: false,
      resolvedBy: actor.uid,
      resolutionReason: resolutionReason.trim(),
      resolvedAt: now.toISOString(),
      version: nextVersion,
      updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    }, { merge: true });

    // Record idempotent receipt
    tx.set(operationRef, {
      operationId,
      actorId: actor.uid,
      companyId,
      kind: 'resolve_hold',
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
      action: 'resolve_remote_financial_hold',
      targetId: attendanceId,
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
  declareRemoteIncident,
  resolveRemoteFinancialHold,
  holdError,
};
