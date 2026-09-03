'use strict';

const crypto = require('crypto');
const { isHrOrAdmin } = require('./phase007-authorization');

const clean = (value, max = 500) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
const safeId = (value) => /^[A-Za-z0-9_-]{8,160}$/.test(String(value || ''));
const digest = (...parts) => crypto.createHash('sha256').update(parts.join('\u001f')).digest('hex').slice(0, 40);
const stamp = () => new Date().toISOString();

function meetingApproverCapable(user = {}) {
  return ['manager', 'team_leader', 'ceo', 'super_admin', 'admin', 'hr_admin', 'hr_manager', 'hr_staff', 'hr']
    .includes(String(user.role || '').toLowerCase()) && user.isActive !== false;
}

function approverLabel(user = {}) {
  const role = String(user.role || '').toLowerCase();
  if (role === 'ceo') return 'الرئيس التنفيذي';
  if (['hr', 'hr_admin', 'hr_manager', 'hr_staff'].includes(role)) return 'الموارد البشرية';
  if (['admin', 'super_admin'].includes(role)) return 'إدارة النظام';
  return 'مدير مباشر';
}

async function listMeetingApprovers({ db }) {
  const snapshot = await db.collection('users').where('isActive', '==', true).limit(500).get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter(meetingApproverCapable)
    .map((user) => ({
      id: user.id,
      name: clean(user.displayName || user.name || 'مسؤول', 160),
      employeeCode: clean(user.employeeId || user.employeeCode, 80),
      department: clean(user.department || user.departmentName, 120),
      roleLabel: approverLabel(user),
    }))
    .sort((a, b) => a.name.localeCompare(b.name, 'ar'));
}

async function checkAvailability({ db, roomId, startAt, endAt }) {
  const reservations = await db.collection('meetingRequests')
    .where('roomId', '==', roomId).where('status', 'in', ['pending', 'approved']).get();
  const occupied = reservations.docs.some((doc) => {
    const value = doc.data();
    const from = value.startAt?.toDate?.();
    const to = value.endAt?.toDate?.();
    return from instanceof Date && to instanceof Date && startAt < to && from < endAt;
  });
  return !occupied;
}

async function queueNotification(db, admin, { recipientId, key, title, body, data }) {
  const id = `meeting-${digest(key, recipientId)}`;
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, {
      notificationId: id, type: 'meeting_request', title, body, data,
      isRead: false, pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('users').doc(recipientId), {
      unreadNotifications: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  });
}

async function ensureDefaultRooms(db, admin) {
  const seedRef = db.collection('meetingRoomConfig').doc('initialised');
  await db.runTransaction(async (tx) => {
    if ((await tx.get(seedRef)).exists) return;
    const rooms = [
      ['office', 'المكتب'], ['small-room', 'غرفة اجتماعات صغيرة'], ['large-room', 'غرفة اجتماعات كبيرة'],
    ];
    for (const [id, nameAr] of rooms) {
      tx.set(db.collection('meetingRooms').doc(id), {
        nameAr, normalizedName: nameAr, isActive: true, seeded: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    tx.set(seedRef, { initialisedAt: admin.firestore.FieldValue.serverTimestamp() });
  });
}

async function listRooms({ db, admin, actor }) {
  await ensureDefaultRooms(db, admin);
  const snapshot = await db.collection('meetingRooms').orderBy('nameAr').get();
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((room) => isHrOrAdmin({ ...actor, active: true }) || room.isActive === true);
}

async function saveRoom({ db, admin, actor, body, roomId = '' }) {
  if (!isHrOrAdmin({ ...actor, active: true })) throw new Error('لا تملك صلاحية إدارة قاعات الاجتماعات.');
  const operationId = clean(body.operationId, 160);
  const nameAr = clean(body.nameAr, 120);
  if (!safeId(operationId) || !nameAr) throw new Error('اسم القاعة مطلوب.');
  const ref = db.collection('meetingRooms').doc(roomId || `room-${digest(actor.uid, operationId)}`);
  await db.runTransaction(async (tx) => {
    const duplicate = await tx.get(db.collection('meetingRooms').where('normalizedName', '==', nameAr).limit(1));
    if (!roomId && !duplicate.empty) throw new Error('توجد قاعة بالاسم نفسه.');
    tx.set(ref, {
      nameAr, normalizedName: nameAr,
      descriptionAr: clean(body.descriptionAr, 300),
      capacity: Math.max(0, Math.min(1000, Number(body.capacity) || 0)),
      isActive: body.isActive !== false,
      updatedBy: actor.uid, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(roomId ? {} : { createdBy: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp() }),
    }, { merge: true });
  });
  return { roomId: ref.id };
}

async function createMeeting({ db, admin, actor, body }) {
  const operationId = clean(body.operationId, 160);
  const managerId = clean(body.managerId, 160);
  const roomId = clean(body.roomId, 160);
  const purpose = clean(body.purpose, 700);
  const startAt = new Date(String(body.startAt || ''));
  const endAt = new Date(String(body.endAt || ''));
  if (!safeId(operationId) || !safeId(managerId) || !safeId(roomId) || !purpose ||
      Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime()) || startAt >= endAt || startAt <= new Date()) {
    throw new Error('أكمل المدير والقاعة والموعد والسبب بصورة صحيحة.');
  }
  if (managerId === actor.uid) throw new Error('لا يمكنك طلب اجتماع مع نفسك.');
  await ensureDefaultRooms(db, admin);
  const [managerSnap, roomSnap, requesterSnap] = await Promise.all([
    db.collection('users').doc(managerId).get(), db.collection('meetingRooms').doc(roomId).get(), db.collection('users').doc(actor.uid).get(),
  ]);
  if (!managerSnap.exists || !meetingApproverCapable(managerSnap.data())) {
    throw new Error('اختر مديراً أو مسؤول موارد بشرية أو مدير نظام أو رئيساً تنفيذياً نشطاً فقط.');
  }
  if (!roomSnap.exists || roomSnap.data().isActive !== true) throw new Error('القاعة المختارة غير متاحة.');
  const requestRef = db.collection('meetingRequests').doc(`meeting-${digest(actor.uid, operationId)}`);
  const receiptRef = db.collection('meetingRequestOperations').doc(`create-${digest(actor.uid, operationId)}`);
  const result = await db.runTransaction(async (tx) => {
    const old = await tx.get(receiptRef);
    if (old.exists) return { requestId: old.data().requestId, replayed: true };
    const reservations = await tx.get(db.collection('meetingRequests')
      .where('roomId', '==', roomId).where('status', 'in', ['pending', 'approved']));
    const collision = reservations.docs.some((doc) => {
      const value = doc.data(); const from = value.startAt?.toDate?.(); const to = value.endAt?.toDate?.();
      return from instanceof Date && to instanceof Date && startAt < to && from < endAt;
    });
    if (collision) throw new Error('القاعة محجوزة في هذا الموعد. اختر وقتاً أو قاعة أخرى.');
    const manager = managerSnap.data() || {};
    const requester = requesterSnap.data() || {};
    const room = roomSnap.data() || {};
    const route = [{ stageId: `meeting:${requestRef.id}:1`, order: 1, approverId: managerId,
      approverName: clean(manager.displayName || manager.name || 'مدير', 160), state: 'pending' }];
    tx.set(requestRef, {
      requesterId: actor.uid, requesterName: clean(requester.displayName || requester.name || actor.displayName || 'موظف', 160),
      managerId, managerName: route[0].approverName, roomId, roomName: clean(room.nameAr, 120),
      purpose, startAt: admin.firestore.Timestamp.fromDate(startAt), endAt: admin.firestore.Timestamp.fromDate(endAt),
      status: 'pending', approvalRoute: route, approvalHistory: [{ action: 'submitted', actorId: actor.uid, at: stamp() }],
      currentApproverId: managerId, currentApprovalIndex: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(receiptRef, { requestId: requestRef.id, operationId, actorId: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return { requestId: requestRef.id, replayed: false };
  });
  if (!result.replayed) await Promise.all([
    queueNotification(db, admin, { recipientId: managerId, key: `${result.requestId}:turn`, title: 'طلب اجتماع جديد', body: 'لديك طلب اجتماع يحتاج قرارك.', data: { path: '/meeting/approvals', requestId: result.requestId } }),
    queueNotification(db, admin, { recipientId: actor.uid, key: `${result.requestId}:submitted`, title: 'تم إرسال طلب الاجتماع', body: 'بانتظار قرار المسؤول المختار.', data: { path: '/meeting/history', requestId: result.requestId } }),
  ]);
  return result;
}

async function decideMeeting({ db, admin, actor, requestId, body }) {
  const operationId = clean(body.operationId, 160);
  const decision = body.decision === 'approved' ? 'approved' : body.decision === 'rejected' ? 'rejected' : '';
  if (!safeId(requestId) || !safeId(operationId) || !decision) throw new Error('قرار الاجتماع غير صالح.');
  const ref = db.collection('meetingRequests').doc(requestId);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('طلب الاجتماع غير موجود.');
    const request = snap.data();
    if (request.currentApproverId !== actor.uid || request.status !== 'pending') throw new Error('هذا الطلب ليس بانتظار قرارك.');
    tx.update(ref, { status: decision, currentApproverId: null, currentApprovalIndex: 1,
      approvalRoute: [{ ...request.approvalRoute[0], state: decision, decidedAt: stamp() }],
      approvalHistory: [...(request.approvalHistory || []), { action: decision, actorId: actor.uid, comment: clean(body.comment, 500), at: stamp() }],
      updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    return { requesterId: request.requesterId };
  });
  await queueNotification(db, admin, { recipientId: result.requesterId, key: `${requestId}:${decision}`, title: decision === 'approved' ? 'تمت الموافقة على الاجتماع' : 'تم رفض طلب الاجتماع', body: decision === 'approved' ? 'تم تأكيد موعد الاجتماع.' : 'راجع تفاصيل الطلب لمعرفة السبب.', data: { path: '/meeting/history', requestId } });
  return { requestId, decision };
}

async function cancelMeeting({ db, admin, actor, requestId, body }) {
  const operationId = clean(body.operationId, 160);
  if (!safeId(requestId) || !safeId(operationId)) throw new Error('تعذر إلغاء طلب الاجتماع.');
  const ref = db.collection('meetingRequests').doc(requestId);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('طلب الاجتماع غير موجود.');
    const request = snap.data() || {};
    if (request.requesterId !== actor.uid) throw new Error('لا تملك صلاحية إلغاء هذا الطلب.');
    if (request.status !== 'pending') throw new Error('يمكن إلغاء الطلبات التي ما زالت قيد المراجعة فقط.');
    tx.update(ref, {
      status: 'cancelled', currentApproverId: null,
      approvalRoute: (request.approvalRoute || []).map((stage) =>
        stage.state === 'pending' ? { ...stage, state: 'cancelled', decidedAt: stamp() } : stage),
      approvalHistory: [...(request.approvalHistory || []), { action: 'cancelled', actorId: actor.uid, at: stamp() }],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { approverId: request.currentApproverId };
  });
  if (result.approverId) {
    await queueNotification(db, admin, { recipientId: result.approverId, key: `${requestId}:cancelled`, title: 'تم إلغاء طلب اجتماع', body: 'ألغى مقدم الطلب موعد الاجتماع قبل اتخاذ القرار.', data: { path: '/meeting/approvals', requestId } });
  }
  return { requestId, status: 'cancelled' };
}

function serializeMeeting(doc) {
  const value = doc.data() || {};
  const at = (field) => value[field]?.toDate?.()?.toISOString?.() || null;
  return {
    id: doc.id, requesterId: value.requesterId, requesterName: value.requesterName,
    managerId: value.managerId, managerName: value.managerName, roomName: value.roomName,
    purpose: value.purpose, status: value.status, startAt: at('startAt'), endAt: at('endAt'),
    approvalRoute: value.approvalRoute || [], approvalHistory: value.approvalHistory || [],
  };
}

async function listMeetingRequests({ db, actor, queue = false }) {
  const query = queue
    ? db.collection('meetingRequests').where('currentApproverId', '==', actor.uid).limit(100)
    : db.collection('meetingRequests').where('requesterId', '==', actor.uid).limit(100);
  const snapshot = await query.get();
  return snapshot.docs.map(serializeMeeting).sort((a, b) => String(b.startAt || '').localeCompare(String(a.startAt || '')));
}

module.exports = { listRooms, saveRoom, createMeeting, decideMeeting, cancelMeeting, listMeetingApprovers, checkAvailability, listMeetingRequests };
