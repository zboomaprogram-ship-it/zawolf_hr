'use strict';

const crypto = require('crypto');
const { isHrOrAdmin } = require('./phase007-authorization');

const CAIRO_TIME_ZONE = 'Africa/Cairo';
const clean = (value, max = 500) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
const safeId = (value) => /^[A-Za-z0-9_-]{8,160}$/.test(String(value || ''));
const operationKey = (actorId, operationId) => crypto
  .createHash('sha256').update(`${actorId}\u001f${operationId}`).digest('hex').slice(0, 40);
const normalizeSearch = (value) => clean(value, 500)
  .toLowerCase()
  .replace(/[\u064B-\u065F\u0670]/g, '')
  .replace(/[أإآ]/g, 'ا')
  .replace(/ى/g, 'ي')
  .replace(/ة/g, 'ه');

function cairoParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: CAIRO_TIME_ZONE,
    year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short',
  }).formatToParts(date);
  const get = (type) => parts.find((part) => part.type === type)?.value || '';
  return { dateKey: `${get('year')}-${get('month')}-${get('day')}`, weekday: get('weekday') };
}

function timestampDateKey(value) {
  const date = typeof value?.toDate === 'function' ? value.toDate() : value;
  return date instanceof Date && !Number.isNaN(date.getTime()) ? cairoParts(date).dateKey : '';
}

function isWorkDay(user, weekday) {
  const map = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  const days = user.workSchedule?.workDays;
  return Array.isArray(days) && days.length ? days.includes(map[weekday]) : weekday !== 'Fri';
}

function approvedLeaveOn(leaves, dateKey) {
  return leaves.docs.some((doc) => {
    const leave = doc.data() || {};
    const start = timestampDateKey(leave.startDate);
    const end = timestampDateKey(leave.endDate);
    return leave.status === 'approved' && start && end && start <= dateKey && dateKey <= end;
  });
}

async function queueNotification(db, admin, { employeeId, operationId, eventType, effectiveAt }) {
  const notificationId = `manual-attendance-${operationKey(employeeId, operationId)}`;
  const ref = db.collection('notifications').doc(employeeId).collection('items').doc(notificationId);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    const label = eventType === 'checkIn' ? 'حضور' : 'انصراف';
    tx.set(ref, {
      notificationId,
      type: 'manual_attendance_recorded',
      title: 'تم تسجيل حضور يدوي',
      body: `سجلت الموارد البشرية ${label} يدويًا بتاريخ ${effectiveAt}.`,
      data: { type: 'manual_attendance_recorded' },
      isRead: false,
      pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('users').doc(employeeId), {
      unreadNotifications: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  });
}

async function recordManualAttendance({ db, admin, actor, body }) {
  if (!isHrOrAdmin({ ...actor, active: true })) {
    throw new Error('لا تملك صلاحية تسجيل الحضور اليدوي.');
  }
  const operationId = clean(body?.operationId, 160);
  const employeeId = clean(body?.employeeId, 160);
  const eventType = ['checkOut', 'checkIn', 'disableCheckOut'].includes(body?.eventType) ? body.eventType : '';
  const reason = clean(body?.reason, 500);
  const effectiveAt = new Date(String(body?.effectiveAt || ''));
  if (!safeId(operationId) || !safeId(employeeId) || !eventType || !reason || Number.isNaN(effectiveAt.getTime())) {
    throw new Error('أكمل الموظف ونوع الحضور والوقت والسبب بصورة صحيحة.');
  }
  const now = new Date();
  const current = cairoParts(now);
  const effective = cairoParts(effectiveAt);
  if (effective.dateKey !== current.dateKey || effectiveAt.getTime() > now.getTime() + 5 * 60 * 1000) {
    throw new Error('يسمح بتسجيل حضور اليوم فقط وفي وقت حالي أو سابق.');
  }
  const employeeRef = db.collection('users').doc(employeeId);
  const attendanceId = `${employeeId}_${effective.dateKey}`;
  const attendanceRef = db.collection('attendance').doc(attendanceId);
  const receiptRef = db.collection('attendanceManualOperations').doc(`manual-${operationKey(actor.uid, operationId)}`);
  const auditRef = db.collection('auditLogs').doc(`manual-attendance-${operationKey(actor.uid, operationId)}`);
  const [employeeSnap, dayOffSnap, leaves] = await Promise.all([
    employeeRef.get(),
    db.collection('companyDayOffs').doc(effective.dateKey).get(),
    db.collection('leaves').where('userId', '==', employeeId).get(),
  ]);
  const employee = employeeSnap.data() || {};
  if (!employeeSnap.exists || employee.isActive === false) throw new Error('حساب الموظف غير نشط أو غير موجود.');
  if (!isWorkDay(employee, effective.weekday)) throw new Error('هذا اليوم ليس يوم عمل للموظف.');
  if (dayOffSnap.exists && dayOffSnap.data()?.isActive === true) throw new Error('لا يمكن تسجيل حضور يدوي في عطلة الشركة.');
  if (approvedLeaveOn(leaves, effective.dateKey)) throw new Error('لدى الموظف إجازة معتمدة في هذا اليوم.');

  const result = await db.runTransaction(async (tx) => {
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) return { replayed: true, ...(receipt.data()?.result || {}) };
    const attendance = await tx.get(attendanceRef);
    const data = attendance.data() || {};
    if (eventType === 'checkIn' && data.checkInTime) throw new Error('تم تسجيل الحضور بالفعل لهذا اليوم.');
    if (eventType === 'checkOut' && !data.checkInTime) throw new Error('يجب تسجيل الحضور أولاً قبل الانصراف.');
    if (eventType === 'checkOut' && data.checkOutTime) throw new Error('تم تسجيل الانصراف بالفعل لهذا اليوم.');
    const existingCheckIn = data.checkInTime?.toDate?.();
    if (eventType === 'checkOut' && existingCheckIn instanceof Date && effectiveAt <= existingCheckIn) {
      throw new Error('وقت الانصراف يجب أن يكون بعد وقت الحضور.');
    }
    const manualEvent = {
      operationId, actorId: actor.uid, actorName: clean(actor.displayName || actor.name || 'HR', 160),
      reason, effectiveAt: admin.firestore.Timestamp.fromDate(effectiveAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(), source: 'hr_manual',
    };
    const base = attendance.exists ? {} : {
      userId: employeeId, employeeId: clean(employee.employeeId || employee.employeeCode, 80),
      employeeName: clean(employee.displayName || employee.name, 160), date: effective.dateKey,
      securityProtocolVersion: 2,
    };
    const patch = eventType === 'checkIn'
      ? { ...base, checkInTime: admin.firestore.Timestamp.fromDate(effectiveAt), localCheckInTime: admin.firestore.Timestamp.fromDate(effectiveAt), manualCheckIn: manualEvent, entrySource: 'hr_manual' }
      : eventType === 'checkOut'
      ? { ...base, checkOutTime: admin.firestore.Timestamp.fromDate(effectiveAt), localCheckOutTime: admin.firestore.Timestamp.fromDate(effectiveAt), manualCheckOut: manualEvent, entrySource: 'hr_manual' }
      : { ...base, checkoutPolicyEnabled: false, manualDisableCheckOut: manualEvent };
    tx.set(attendanceRef, patch, { merge: true });
    const response = { attendanceId, employeeId, eventType, status: 'recorded' };
    tx.set(receiptRef, { operationId, actorId: actor.uid, employeeId, attendanceId, eventType, reason, effectiveAt: admin.firestore.Timestamp.fromDate(effectiveAt), result: response, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.set(auditRef, { action: 'manual_attendance_recorded', actorId: actor.uid, employeeId, attendanceId, eventType, reason, effectiveAt: admin.firestore.Timestamp.fromDate(effectiveAt), createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return { replayed: false, ...response };
  });
  if (!result.replayed) await queueNotification(db, admin, { employeeId, operationId, eventType, effectiveAt: effective.dateKey });
  return result;
}

async function listManualAttendanceEmployees({ db, actor, query }) {
  if (!isHrOrAdmin({ ...actor, active: true })) {
    throw new Error('لا تملك صلاحية عرض حالة الحضور اليدوي.');
  }
  const queryText = normalizeSearch(query);
  const userSnapshot = await db.collection('users')
    .where('isActive', '==', true)
    .limit(500)
    .get();
  const employees = userSnapshot.docs
    .map((doc) => {
      const user = doc.data() || {};
      return {
        id: doc.id,
        name: clean(user.displayName || user.name || 'موظف', 160),
        employeeCode: clean(user.employeeId || user.employeeCode, 80),
        department: clean(user.department || user.departmentName, 120),
        email: clean(user.email, 160),
      };
    })
    .filter((employee) => !queryText || normalizeSearch(
      `${employee.name} ${employee.employeeCode} ${employee.department} ${employee.email}`,
    ).includes(queryText))
    .slice(0, 50);
  const dateKey = cairoParts().dateKey;
  const statuses = await Promise.all(employees.map(async (employee) => {
    const attendance = (await db.collection('attendance').doc(`${employee.id}_${dateKey}`).get()).data() || {};
    const checkIn = attendance.checkInTime?.toDate?.() || null;
    const checkOut = attendance.checkOutTime?.toDate?.() || null;
    return {
      ...employee,
      isCheckedIn: Boolean(checkIn),
      isCheckedOut: Boolean(checkOut),
      checkInAt: checkIn ? checkIn.toISOString() : null,
      checkOutAt: checkOut ? checkOut.toISOString() : null,
    };
  }));
  return statuses;
}

module.exports = { recordManualAttendance, listManualAttendanceEmployees, cairoParts };
