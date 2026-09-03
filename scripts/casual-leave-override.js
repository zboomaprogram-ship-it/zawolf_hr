'use strict';

const crypto = require('crypto');
const { isHrOrAdmin } = require('./phase007-authorization');

const hash = (...values) => crypto.createHash('sha256').update(values.join('\u001f')).digest('hex').slice(0, 40);
const clean = (value, max = 500) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);

function cairoDate() {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
  const get = (type) => parts.find((part) => part.type === type)?.value || '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function leaveDate(value) {
  const date = value?.toDate?.() || value;
  if (!(date instanceof Date)) return '';
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
  const get = (type) => parts.find((part) => part.type === type)?.value || '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

async function notify(db, admin, recipientId, key, title, body, data) {
  if (!recipientId) return;
  const id = `casual-override-${hash(key, recipientId)}`;
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, { notificationId: id, type: 'casual_leave_review', title, body, data, isRead: false, pushSent: false, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.set(db.collection('users').doc(recipientId), { unreadNotifications: admin.firestore.FieldValue.increment(1) }, { merge: true });
  });
}

async function overrideAutoApprovedCasualLeave({ db, admin, actor, leaveId, body }) {
  if (!isHrOrAdmin({ ...actor, active: true })) throw new Error('لا تملك صلاحية تعديل الإجازة العارضة.');
  const operationId = clean(body?.operationId, 160);
  const reason = clean(body?.reason, 500);
  if (!/^[A-Za-z0-9_-]{8,160}$/.test(operationId) || !reason) throw new Error('سبب التحويل للمراجعة مطلوب.');
  const ref = db.collection('leaves').doc(leaveId);
  const operationRef = db.collection('casualLeaveOverrideOperations').doc(hash(actor.uid, operationId));
  const outcome = await db.runTransaction(async (tx) => {
    const [old, receipt] = await Promise.all([tx.get(ref), tx.get(operationRef)]);
    if (receipt.exists) return receipt.data().result;
    if (!old.exists) throw new Error('طلب الإجازة غير موجود.');
    const leave = old.data() || {};
    if (leave.leaveType !== 'casual' || leave.autoApproved !== true || leave.status !== 'approved') throw new Error('هذا الطلب ليس إجازة عارضة معتمدة تلقائياً قابلة للمراجعة.');
    if (leaveDate(leave.startDate) <= cairoDate()) throw new Error('لا يمكن تحويل إجازة بدأت أو نُفذت بالفعل للمراجعة.');
    const managerId = String((leave.managerIds || [])[0] || leave.managerId || '').trim();
    const nextStatus = managerId ? 'pending_manager' : 'pending_hr';
    tx.update(ref, {
      status: nextStatus, autoApprovalOverride: { actorId: actor.uid, actorName: clean(actor.displayName || actor.name || 'HR', 160), reason, requestedAt: new Date().toISOString() },
      autoApprovedOverridden: true, currentApproverId: managerId || actor.uid,
      approvalHistory: [...(leave.approvalHistory || []), { stage: 'auto_approval_overridden', status: 'pending', actorId: actor.uid, actorName: clean(actor.displayName || actor.name || 'HR', 160), reason, at: new Date().toISOString() }],
      reviewedAt: null, reviewedBy: null, reviewerName: null, reviewerComment: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const result = { leaveId, employeeId: leave.userId, managerId, status: nextStatus };
    tx.set(operationRef, { operationId, actorId: actor.uid, result, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return result;
  });
  await Promise.all([
    notify(db, admin, outcome.employeeId, `${leaveId}:employee`, 'تم تحويل الإجازة العارضة للمراجعة', 'حوّلت الموارد البشرية الإجازة إلى مسار مراجعة. راجع سجل طلباتك.', { path: '/employee/requests', leaveId }),
    outcome.managerId ? notify(db, admin, outcome.managerId, `${leaveId}:turn`, 'إجازة عارضة تحتاج مراجعتك', 'هناك إجازة عارضة حوّلتها الموارد البشرية للمراجعة.', { path: '/manager/requests', leaveId }) : Promise.resolve(),
  ]);
  return outcome;
}

async function editCasualLeaveDates({ db, admin, actor, leaveId, body }) {
  if (!isHrOrAdmin({ ...actor, active: true })) throw new Error('لا تملك صلاحية تعديل الإجازة العارضة.');
  const operationId = clean(body?.operationId, 160);
  const startDateStr = clean(body?.startDate, 30);
  const endDateStr = clean(body?.endDate, 30);
  const reason = clean(body?.reason, 500);
  if (!/^[A-Za-z0-9_-]{8,160}$/.test(operationId)) throw new Error('معرف العملية غير صحيح.');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDateStr) || !/^\d{4}-\d{2}-\d{2}$/.test(endDateStr)) {
    throw new Error('حدد تاريخ بداية ونهاية صحيحين.');
  }

  const start = new Date(startDateStr);
  const end = new Date(endDateStr);
  if (end < start) throw new Error('تاريخ النهاية يسبق البداية.');

  const daysCount = Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

  const ref = db.collection('leaves').doc(leaveId);
  const operationRef = db.collection('casualLeaveEditOperations').doc(hash(actor.uid, operationId));

  const outcome = await db.runTransaction(async (tx) => {
    const [old, receipt] = await Promise.all([tx.get(ref), tx.get(operationRef)]);
    if (receipt.exists) return receipt.data().result;
    if (!old.exists) throw new Error('طلب الإجازة غير موجود.');
    const leave = old.data() || {};
    if (leave.leaveType !== 'casual' && leave.leaveType !== 'day_off' && !leave.autoApproved) {
      throw new Error('تعديل موعد الإجازة غير ممكن لهذا الطلب.');
    }

    const previousStart = leaveDate(leave.startDate);
    const previousEnd = leaveDate(leave.endDate);

    tx.update(ref, {
      startDate: admin.firestore.Timestamp.fromDate(start),
      endDate: admin.firestore.Timestamp.fromDate(end),
      numberOfDays: daysCount,
      editedByHr: {
        actorId: actor.uid,
        actorName: clean(actor.displayName || actor.name || 'HR', 160),
        reason: reason || 'تعديل تاريخ الإجازة العارضة بواسطة الموارد البشرية',
        previousStart,
        previousEnd,
        editedAt: new Date().toISOString(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const result = {
      leaveId,
      employeeId: leave.userId,
      managerId: String((leave.managerIds || [])[0] || leave.managerId || '').trim(),
      newStartDate: startDateStr,
      newEndDate: endDateStr,
      numberOfDays: daysCount,
    };
    tx.set(operationRef, { operationId, actorId: actor.uid, result, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return result;
  });

  await Promise.all([
    notify(db, admin, outcome.employeeId, `${leaveId}:edited:emp`, 'تم تعديل موعد إجازتك العارضة', `قامت الموارد البشرية بتعديل موعد إجازتك العارضة لتصبح من ${startDateStr} إلى ${endDateStr}.`, { path: '/employee/requests', leaveId }),
    outcome.managerId ? notify(db, admin, outcome.managerId, `${leaveId}:edited:mgr`, 'تعديل موعد إجازة عارضة', `قامت الموارد البشرية بتعديل موعد الإجازة العارضة للموظف لتصبح من ${startDateStr} إلى ${endDateStr}.`, { path: '/manager/requests', leaveId }) : Promise.resolve(),
  ]);
  return outcome;
}

module.exports = { overrideAutoApprovedCasualLeave, editCasualLeaveDates };
