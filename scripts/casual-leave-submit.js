'use strict';

const crypto = require('crypto');

function clean(value, max = 500) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
}

function parseDay(value) {
  const text = clean(value, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) throw new Error('تاريخ الإجازة غير صالح.');
  const date = new Date(`${text}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== text) throw new Error('تاريخ الإجازة غير صالح.');
  return date;
}

function operationKey(actorId, operationId) {
  return crypto.createHash('sha256').update(`${actorId}|${operationId}`).digest('hex').slice(0, 40);
}

async function submitCasualLeave({ db, admin, actor, body = {} }) {
  const operationId = clean(body.operationId, 160);
  const leaveId = clean(body.leaveId, 160);
  const reason = clean(body.reason, 1000);
  const workHandoverTo = clean(body.workHandoverTo, 500);
  const numberOfDays = Number(body.numberOfDays);
  const startDate = parseDay(body.startDate);
  const endDate = parseDay(body.endDate);
  if (!operationId || !/^[A-Za-z0-9_-]{8,160}$/.test(leaveId)) throw new Error('معرّف العملية غير صالح.');
  if (!reason || !workHandoverTo) throw new Error('سبب الإجازة وتسليم العمل مطلوبان.');
  if (!Number.isFinite(numberOfDays) || numberOfDays <= 0 || numberOfDays > 7) throw new Error('عدد أيام الإجازة العارضة غير صالح.');
  if (endDate < startDate) throw new Error('تاريخ نهاية الإجازة يسبق تاريخ البداية.');

  const userRef = db.collection('users').doc(actor.uid);
  const leaveRef = db.collection('leaves').doc(leaveId);
  const opRef = db.collection('requestSubmissionOperations').doc(`casual-${operationKey(actor.uid, operationId)}`);
  const overlapQuery = db.collection('leaves')
    .where('userId', '==', actor.uid)
    .where('startDate', '<=', admin.firestore.Timestamp.fromDate(endDate))
    .limit(50);
  let replayed = false;
  await db.runTransaction(async (tx) => {
    const [userSnap, leaveSnap, opSnap, overlapSnap] = await Promise.all([
      tx.get(userRef), tx.get(leaveRef), tx.get(opRef), tx.get(overlapQuery),
    ]);
    if (opSnap.exists || leaveSnap.exists) { replayed = true; return; }
    if (!userSnap.exists || userSnap.data()?.isActive === false) throw new Error('حساب الموظف غير نشط.');
    const user = userSnap.data() || {};
    const balance = user.leaveBalance || {};
    const casual = Number(balance.casual ?? 0);
    const total = Number(balance.daysOff ?? balance.annual ?? 0);
    if (casual < numberOfDays || total < numberOfDays) throw new Error('رصيد الإجازة العارضة غير كافٍ.');
    const overlaps = overlapSnap.docs.some((doc) => {
      if (doc.id === leaveId) return false;
      const value = doc.data() || {};
      if (!['approved', 'pending_manager', 'pending_hr', 'pending_ceo'].includes(value.status)) return false;
      const existingEnd = value.endDate?.toDate?.();
      return existingEnd instanceof Date && existingEnd >= startDate;
    });
    if (overlaps) throw new Error('يوجد طلب إجازة آخر متداخل مع هذه الفترة.');
    const employeeId = clean(user.employeeId || user.employeeCode, 80);
    const employeeName = clean(user.displayName || user.name, 160);
    const department = clean(user.department, 160);
    const submittedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.set(leaveRef, {
      userId: actor.uid,
      employeeId,
      employeeName,
      department,
      locationId: clean(user.locationId || body.locationId, 160),
      jobTitle: clean(user.position || user.jobTitle, 160),
      managerId: '', managerIds: [], managerNames: [], managerApprovalIndex: 0,
      managerApprovalTotal: 0, managerApprovalTrail: [],
      leaveType: 'casual', startDate: admin.firestore.Timestamp.fromDate(startDate),
      endDate: admin.firestore.Timestamp.fromDate(endDate), numberOfDays,
      reason, workHandoverTo, attachmentUrl: clean(body.attachmentUrl, 1000) || null,
      status: 'approved', autoApproved: true, requiresHrApproval: false,
      requiresCeoApproval: false, deductsLeaveBalance: true,
      leaveBalanceKey: 'casual', leaveBalanceKeys: ['casual', 'daysOff'],
      requiresFullDaySalaryDeduction: false, convertToAnnual: false,
      submittedAt, isRead: false, currentApprovalIndex: 0,
      currentApproverId: '', currentApproverName: '',
      approvalHistory: [
        { stage: 'submitted', status: 'completed', actorId: actor.uid, actorName: employeeName, at: new Date().toISOString() },
        { stage: 'auto_approved', status: 'approved', actorId: 'system', actorName: 'النظام', at: new Date().toISOString() },
      ],
      reviewedAt: submittedAt, reviewedBy: 'system', reviewerName: 'النظام (اعتماد تلقائي)',
      reviewerComment: 'تم اعتماد الإجازة العارضة تلقائياً.',
    });
    tx.update(userRef, {
      'leaveBalance.casual': admin.firestore.FieldValue.increment(-numberOfDays),
      'leaveBalance.daysOff': admin.firestore.FieldValue.increment(-numberOfDays),
      lastAutoApprovedCasualLeaveId: leaveId,
    });
    tx.set(opRef, { operationId, leaveId, actorId: actor.uid, createdAt: submittedAt });
  });

  if (!replayed) {
    const id = `leave-auto-approved-${leaveId}`;
    const notificationRef = db.collection('notifications').doc(actor.uid).collection('items').doc(id);
    await db.runTransaction(async (tx) => {
      if ((await tx.get(notificationRef)).exists) return;
      tx.set(notificationRef, {
        notificationId: id, type: 'leave_auto_approved', title: 'تم اعتماد الإجازة العارضة',
        body: `تم اعتماد الإجازة العارضة وخصم ${numberOfDays} يوم من الرصيد.`,
        data: { leaveId, route: '/employee/requests' }, isRead: false, pushSent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(userRef, { unreadNotifications: admin.firestore.FieldValue.increment(1) }, { merge: true });
    });
  }
  return { leaveId, status: 'approved', replayed };
}

module.exports = { submitCasualLeave, parseDay, operationKey };
