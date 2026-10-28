'use strict';

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function queryError(code, messageAr = 'تعذر استعلام بيانات العمل عن بعد.') {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

function requireQueryActor(actor) {
  if (!actor || actor.active !== true || !SAFE_ID.test(String(actor.uid || '')) || !SAFE_ID.test(String(actor.companyId || ''))) {
    throw queryError('unauthenticated', 'يرجى تسجيل الدخول مرة أخرى.');
  }
}

async function listRemoteDays({ db, actor, filters = {}, cursor, limit = 50 }) {
  requireQueryActor(actor);

  const boundedLimit = Math.max(1, Math.min(Number(limit) || 50, 100));
  const companyId = actor.companyId;
  const caps = Array.isArray(actor.capabilities) ? actor.capabilities : [];

  const isHr = caps.includes('hr_admin') || caps.includes('view_company_attendance');
  const isManager = caps.includes('manager') || caps.includes('manage_schedules');

  const targetUserId = filters.userId ? String(filters.userId) : null;

  // Normal employees can only query their own days
  if (!isHr && !isManager) {
    if (targetUserId && targetUserId !== actor.uid) {
      throw queryError('not_authorized', 'لا يمكنك استعراض سجلات موظف آخر.');
    }
  }

  const effectiveUserId = (!isHr && !isManager) ? actor.uid : targetUserId;

  let query = db.collection('attendance');

  if (effectiveUserId) {
    query = query.where('userId', '==', effectiveUserId);
  }
  query = query.where('attendanceMode', '==', 'remote_web');

  const snapshot = await query.limit(boundedLimit).get();
  const docs = snapshot.docs || [];

  const items = docs.map((doc) => {
    const data = doc.data() || {};
    return {
      attendanceId: doc.id,
      userId: data.userId,
      date: data.date,
      attendanceMode: data.attendanceMode || 'remote_web',
      status: data.status || 'present',
      checkInTime: data.checkInTime,
      checkOutTime: data.checkOutTime,
      remoteSessionId: data.remoteSessionId,
      finalizedAt: data.finalizedAt,
      version: data.version || 1,
    };
  });

  const nextCursor = items.length === boundedLimit ? items[items.length - 1].attendanceId : null;

  return {
    items,
    nextCursor,
    totalReturned: items.length,
    limit: boundedLimit,
  };
}

module.exports = {
  listRemoteDays,
  queryError,
};
