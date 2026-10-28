'use strict';

/**
 * Shared attendance finalization helper for remote shifts (Feature 020).
 * Invoked by daily workers, overnight due-event processors, and manual finalization.
 * Reference: specs/020-remote-work-attendance/plan.md (Section 4) & tasks.md (T06)
 */

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function finalizationError(code, messageAr = 'تعذر إقفال وردية العمل عن بعد.') {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

async function finalizeRemoteShift({ db, admin, attendanceId, now = new Date() }) {
  if (!SAFE_ID.test(String(attendanceId || ''))) {
    throw finalizationError('invalid_attendance_id', 'معرف الحضور غير صالح.');
  }

  const attendanceRef = db.collection('attendance').doc(attendanceId);

  return db.runTransaction(async (tx) => {
    const attSnap = await tx.get(attendanceRef);
    if (!attSnap.exists) {
      throw finalizationError('attendance_not_found', 'سجل الحضور غير موجود.');
    }

    const attData = attSnap.data() || {};
    const mode = attData.attendanceMode || (attData.isRemote ? 'remote_web' : 'office');
    if (mode !== 'remote_web') {
      return {
        attendanceId,
        status: 'skipped_not_remote',
        serverTime: now.toISOString(),
      };
    }

    if (attData.finalizedAt) {
      return {
        attendanceId,
        status: 'already_finalized',
        finalizedAt: attData.finalizedAt,
        serverTime: now.toISOString(),
      };
    }

    const sessionId = attData.remoteSessionId;
    const companyId = attData.companyId || 'zawolf';
    const nextVersion = (attData.version || 1) + 1;

    // Check if check-out occurred
    const hasCheckOut = Boolean(attData.checkOutTime);

    tx.set(attendanceRef, {
      finalizedAt: now.toISOString(),
      finalizedStatus: hasCheckOut ? 'completed' : 'missing_checkout_finalized',
      version: nextVersion,
      updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    }, { merge: true });

    if (sessionId) {
      const sessionRef = db.collection('remoteWorkSessions').doc(`${companyId}_${sessionId}`);
      const sessionSnap = await tx.get(sessionRef);
      if (sessionSnap.exists) {
        tx.set(sessionRef, {
          finalizedAt: now.toISOString(),
          status: hasCheckOut ? 'completed' : 'finalized_without_checkout',
          version: ((sessionSnap.data()?.version || 1) + 1),
          updatedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
        }, { merge: true });
      }
    }

    // Write immutable audit log
    const auditRef = db.collection('remoteWorkAudit').doc();
    tx.set(auditRef, {
      eventId: auditRef.id,
      companyId,
      actorId: 'system_finalizer',
      action: 'finalize_remote_shift',
      targetId: attendanceId,
      hasCheckOut,
      createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now,
    });

    return {
      attendanceId,
      status: 'finalized',
      hasCheckOut,
      version: nextVersion,
      serverTime: now.toISOString(),
    };
  });
}

module.exports = {
  finalizeRemoteShift,
  finalizationError,
};
