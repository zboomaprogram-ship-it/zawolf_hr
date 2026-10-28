'use strict';

/**
 * Enforces single-mode day lock across all attendance writers (Feature 020).
 * Prevents switching between remote and office modes on the same shift date.
 * Reference: specs/020-remote-work-attendance/plan.md (Section 4)
 */

function modeError(code, messageAr) {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

const VALID_MODES = new Set(['remote_web', 'on_site_mobile', 'office']);

function normalizeMode(mode) {
  if (mode === 'office') return 'on_site_mobile';
  return mode;
}

async function enforceDayMode({ transaction, db, actorId, date, requestedMode, evidence = {} }) {
  if (!actorId || typeof actorId !== 'string') {
    throw modeError('invalid_actor', 'معرف الموظف غير صالح.');
  }
  if (!date || typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw modeError('invalid_date', 'تاريخ الحضور غير صالح.');
  }
  if (!VALID_MODES.has(requestedMode)) {
    throw modeError('invalid_mode', 'نمط الحضور المطلوب غير معروف.');
  }
  const normRequested = normalizeMode(requestedMode);

  const attendanceId = `${actorId}_${date}`;
  const attendanceRef = db.collection('attendance').doc(attendanceId);

  const attendanceSnap = await transaction.get(attendanceRef);
  if (attendanceSnap.exists) {
    const existing = attendanceSnap.data() || {};
    const rawExistingMode = existing.attendanceMode || (existing.isRemote === true ? 'remote_web' : 'on_site_mobile');
    const existingMode = normalizeMode(rawExistingMode);
    if (existingMode !== normRequested) {
      throw modeError(
        'mode_locked',
        existingMode === 'remote_web'
          ? 'اليوم مقفل بالفعل كعمل عن بعد ولا يمكن تسجيل الحضور المكتبي في نفس اليوم.'
          : 'اليوم مقفل بالفعل كحضور مكتبي ولا يمكن تسجيل العمل عن بعد في نفس اليوم.'
      );
    }
    return {
      allowed: true,
      mode: existingMode,
      attendanceId,
      existingRecord: true,
      currentVersion: existing.version || 1,
    };
  }

  // New day check-in: validate mode-specific evidence
  if (normRequested === 'remote_web') {
    if (!evidence.verifiedProof) {
      throw modeError('credential_unqualified', 'العمل عن بعد يتطلب إثبات الهوية والمصادقة المعتمدة.');
    }
  }

  return {
    allowed: true,
    mode: normRequested,
    attendanceId,
    existingRecord: false,
    currentVersion: 1,
  };
}

module.exports = {
  enforceDayMode,
  modeError,
};
