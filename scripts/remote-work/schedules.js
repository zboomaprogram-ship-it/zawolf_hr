'use strict';

const crypto = require('node:crypto');
const { validateScheduleRevision } = require('./schedule-policy');
const { isoDate } = require('./eligibility');

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function scheduleError(code, messageAr = 'تعذر حفظ جدول العمل عن بعد.') {
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

function requireScheduleActor(actor) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw scheduleError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
  const isManagerOrHr = Array.isArray(actor.capabilities) &&
    (actor.capabilities.includes('manage_schedules') || actor.capabilities.includes('hr_admin') || actor.capabilities.includes('manage_policy_drafts'));
  if (!isManagerOrHr) {
    throw scheduleError('not_authorized', 'لا تملك الصلاحية المطلوبة لتحديد جدول العمل عن بعد.');
  }
}

async function saveRemoteSchedule({ db, admin, actor, command, now = new Date() }) {
  requireScheduleActor(actor);
  if (!command || command.kind !== 'save_schedule') {
    throw scheduleError('invalid_command', 'نوع أمر الجدول غير صالح.');
  }
  const operationId = String(command.operationId || '');
  if (!SAFE_ID.test(operationId)) {
    throw scheduleError('invalid_command', 'معرف العملية غير صالح.');
  }
  const payload = command.payload || {};
  const schedule = payload.schedule;
  if (!schedule || typeof schedule !== 'object') {
    throw scheduleError('invalid_command', 'بيانات الجدول مطلوبة.');
  }

  const companyId = actor.companyId;
  const operationRef = db.collection('remoteWorkOperations').doc(`${companyId}_${actor.uid}_${operationId}`);
  const companyRef = db.collection('companies').doc(companyId);
  const todayStr = isoDate(now) ? now.toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10);
  const payloadHash = hash(payload);

  const scheduleId = schedule.scheduleId && SAFE_ID.test(schedule.scheduleId)
    ? schedule.scheduleId
    : `${companyId}_${schedule.employeeId}_${schedule.startDate}`;

  const scheduleRef = db.collection('remoteWorkSchedules').doc(scheduleId);
  const guardRef = db.collection('remoteWorkCalendarGuards').doc(companyId);

  const receipt = await db.runTransaction(async (tx) => {
    const opSnap = await tx.get(operationRef);
    if (opSnap.exists) {
      const data = opSnap.data() || {};
      if (data.payloadHash !== payloadHash) {
        throw scheduleError('operation_conflict', 'معرف العملية مستخدم لبيانات أخرى.');
      }
      return {
        operationId,
        status: 'already_recorded',
        scheduleId: data.scheduleId || scheduleId,
        version: data.version || 1,
        serverTime: data.serverTime || now.toISOString(),
      };
    }

    const companySnap = await tx.get(companyRef);
    const companyData = companySnap.exists ? (companySnap.data() || {}) : {};
    const policy = companyData.attendancePolicy?.remoteWorkPolicy || {
      eligibility: {
        daysPerWeek: 2,
        allowedWeekdays: [1, 2, 3, 4, 7],
        weekStartDay: 7,
      },
      schedule: {
        startTime: '09:00',
        endTime: '17:00',
        checkInOpenTime: '08:30',
        endDayOffset: 0,
      },
    };

    const currentSchedule = await tx.get(scheduleRef);
    const existingSchedules = [];

    const validation = validateScheduleRevision({
      schedule,
      policy,
      today: todayStr,
      existingSchedules,
    });

    if (!validation.valid) {
      const firstErr = validation.errors[0];
      throw scheduleError(firstErr?.code || 'validation_failed', `بيانات الجدول غير صالحة: ${firstErr?.path}`);
    }

    const nextVersion = currentSchedule.exists ? ((currentSchedule.data()?.version || 1) + 1) : 1;

    const scheduleData = {
      scheduleId,
      companyId,
      employeeId: schedule.employeeId,
      startDate: schedule.startDate,
      endDate: schedule.endDate,
      weekdays: schedule.weekdays,
      status: 'approved',
      version: nextVersion,
      updatedBy: actor.uid,
      updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    };

    tx.set(scheduleRef, scheduleData);

    const userRef = db.collection('users').doc(schedule.employeeId);
    tx.set(userRef, {
      workSchedule: {
        remoteWorkDays: schedule.weekdays,
      },
    }, { merge: true });

    // Monotonically advance calendar guard epoch
    const guardSnap = await tx.get(guardRef);
    const nextEpoch = guardSnap.exists ? ((guardSnap.data()?.epoch || 1) + 1) : 1;
    tx.set(guardRef, {
      companyId,
      epoch: nextEpoch,
      updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    }, { merge: true });

    // Record idempotent receipt
    tx.set(operationRef, {
      operationId,
      actorId: actor.uid,
      companyId,
      kind: 'save_schedule',
      payloadHash,
      scheduleId,
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
      action: 'save_remote_schedule',
      targetId: scheduleId,
      scheduleVersion: nextVersion,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    return {
      operationId,
      status: 'recorded',
      scheduleId,
      version: nextVersion,
      serverTime: now.toISOString(),
    };
  });

  return receipt;
}

module.exports = {
  saveRemoteSchedule,
  requireScheduleActor,
};
