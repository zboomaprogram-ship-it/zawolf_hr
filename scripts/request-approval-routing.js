'use strict';

// Server-owned approval routing.  Keeping the transition here means browser
// clients cannot skip a reviewer by writing a later status directly.
const crypto = require('crypto');

const clean = (value, max = 500) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
const safeId = (value) => /^[A-Za-z0-9_-]{8,160}$/.test(String(value || ''));
const stamp = () => new Date().toISOString();
const eventId = (...parts) => crypto.createHash('sha256').update(parts.join('\u001f')).digest('hex').slice(0, 40);

function isHr(actor) {
  const scope = [actor?.role, actor?.department, actor?.position, actor?.jobTitle]
    .filter(Boolean).join(' ').toLowerCase();
  return ['super_admin', 'admin', 'administrator', 'owner', 'hr', 'hr_admin', 'hr_manager']
    .includes(String(actor?.role || '').toLowerCase()) ||
    /(^|\s)hr(\s|$)/.test(scope) || scope.includes('human resource') ||
    scope.includes('الموارد البشرية') || scope.includes('موارد بشرية');
}

function userName(data = {}) {
  return clean(data.displayName || data.name || data.employeeName || 'موظف', 160);
}

function isActiveUser(data = {}) { return data.isActive !== false; }

async function queueNotification(db, admin, { recipientId, type, title, body, data, key }) {
  if (!recipientId) return;
  const id = `route-${eventId(key, recipientId)}`;
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, {
      notificationId: id,
      type, title, body, data: data || {}, isRead: false, pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('users').doc(recipientId), {
      unreadNotifications: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  });
}

function validateRoute(approvers) {
  if (!Array.isArray(approvers) || approvers.length < 1 || approvers.length > 4) {
    throw new Error('اختر من مسؤول واحد إلى أربعة مسؤولين بالترتيب.');
  }
  const ids = approvers.map((item) => clean(item?.id || item?.uid, 128));
  if (ids.some((id) => !safeId(id)) || new Set(ids).size !== ids.length) {
    throw new Error('مسار الموافقة يحتوي على مستخدمين غير صالحين أو مكررين.');
  }
  return ids;
}

async function createFieldMission({ db, admin, actor, body }) {
  if (!isHr(actor)) throw new Error('لا تتوفر لك صلاحية إنشاء مأمورية.');
  const operationId = clean(body.operationId, 160);
  // One group operation deliberately creates one approval record per employee.
  // This keeps approval history, notifications, rejection and attendance
  // evidence independent while allowing HR to create a shared mission once.
  const employeeUids = [...new Set((Array.isArray(body.employeeUids) ? body.employeeUids : [body.employeeUid])
    .map((value) => clean(value, 128)).filter(Boolean))];
  if (!safeId(operationId) || employeeUids.length < 1 || employeeUids.length > 50 || employeeUids.some((id) => !safeId(id))) {
    throw new Error('اختر من موظف واحد إلى 50 موظفاً بصورة صحيحة.');
  }
  const approverIds = validateRoute(body.approvers);
  const [employeeSnaps, approverSnaps] = await Promise.all([
    Promise.all(employeeUids.map((id) => db.collection('users').doc(id).get())),
    Promise.all(approverIds.map((id) => db.collection('users').doc(id).get())),
  ]);
  if (employeeSnaps.some((snap) => !snap.exists || !isActiveUser(snap.data()))) throw new Error('أحد الموظفين المختارين غير نشط.');
  if (approverSnaps.some((snap) => !snap.exists || !isActiveUser(snap.data()))) {
    throw new Error('أحد مسؤولي الموافقة غير نشط أو لم يعد موجودًا.');
  }
  const missionDate = clean(body.missionDate, 16);
  const startTime = clean(body.startTime, 8);
  const endTime = clean(body.endTime, 8);
  const reason = clean(body.reason, 700);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(missionDate) || !/^\d{2}:\d{2}$/.test(startTime) ||
      !/^\d{2}:\d{2}$/.test(endTime) || startTime >= endTime || !reason) {
    throw new Error('أكمل تاريخ ووقت وسبب المأمورية بصورة صحيحة.');
  }
  const operationRef = db.collection('requestRoutingOperations').doc(`field-mission-${eventId(actor.uid, operationId)}`);
  const missionGroupId = `field-mission-group-${eventId(actor.uid, operationId)}`;
  const missions = employeeSnaps.map((employeeSnap) => {
    const employee = employeeSnap.data();
    const ref = db.collection('administrativeRequests').doc(`field-mission-${eventId(actor.uid, operationId, employeeSnap.id)}`);
    const route = approverSnaps.map((snap, index) => {
      const data = snap.data();
      return {
        stageId: `field-mission:${ref.id}:${index + 1}`, order: index + 1,
        approverId: snap.id, approverName: userName(data), approverRole: clean(data.role, 80),
        labelAr: clean(body.approvers[index]?.labelAr || 'مسؤول الموافقة', 120), state: 'pending',
      };
    });
    return { ref, employeeUid: employeeSnap.id, employee, route };
  });
  await db.runTransaction(async (tx) => {
    if ((await tx.get(operationRef)).exists) return;
    for (const mission of missions) {
      tx.set(mission.ref, {
        userId: mission.employeeUid, employeeId: clean(mission.employee.employeeId || mission.employee.employeeCode, 80),
        employeeName: userName(mission.employee), department: clean(mission.employee.department || mission.employee.departmentName, 160),
        category: 'field_mission', categoryLabel: 'مأمورية / مهمة ميدانية', notes: reason,
        locationId: clean(body.locationId, 128), missionDate, startTime, endTime,
        siteName: clean(body.siteName, 240), requiresReturnToOffice: body.requiresReturnToOffice === true,
        requiresCheckout: body.requiresCheckout === true, status: 'pending_manager', isRead: false,
        missionGroupId, missionGroupSize: missions.length,
        routeKind: 'hr_field_mission', approvalRouteVersion: 1, approvalRoute: mission.route,
        currentApprovalIndex: 0, currentApproverId: mission.route[0].approverId,
        currentApproverName: mission.route[0].approverName, managerId: mission.route[0].approverId,
        managerName: mission.route[0].approverName, managerIds: mission.route.map((stage) => stage.approverId),
        approvalHistory: [{ action: 'submitted', actorId: actor.uid, actorName: actor.displayName || 'HR', at: stamp() }],
        createdByHrId: actor.uid, createdByHrName: clean(actor.displayName || actor.name || 'HR', 160),
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    tx.set(operationRef, { operationId, requestIds: missions.map((mission) => mission.ref.id), missionGroupId, kind: 'field_mission_create', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  await Promise.allSettled(missions.flatMap((mission) => [
    queueNotification(db, admin, { recipientId: mission.employeeUid, type: 'field_mission_under_review', title: 'مأموريتك قيد المراجعة', body: 'أنشأت الموارد البشرية مأمورية لك وهي الآن بانتظار الموافقات.', data: { administrativeRequestId: mission.ref.id, route: '/employee/requests' }, key: `${mission.ref.id}:submitted` }),
    queueNotification(db, admin, { recipientId: mission.route[0].approverId, type: 'field_mission_approval_turn', title: 'مأمورية بانتظار موافقتك', body: `${userName(mission.employee)} لديه مأمورية تحتاج قرارك.`, data: { administrativeRequestId: mission.ref.id, route: '/manager/requests' }, key: `${mission.ref.id}:turn:0` }),
  ]));
  return { requestIds: missions.map((mission) => mission.ref.id), missionGroupId, currentApproverId: missions[0].route[0].approverId };
}

async function decideFieldMission({ db, admin, actor, requestId, body }) {
  if (!safeId(requestId)) throw new Error('معرّف المأمورية غير صالح.');
  const decision = clean(body.decision, 16).toLowerCase();
  const comment = clean(body.comment, 700);
  const operationId = clean(body.operationId, 160);
  if (!['approved', 'rejected'].includes(decision) || !safeId(operationId)) throw new Error('قرار الموافقة غير صالح.');
  const ref = db.collection('administrativeRequests').doc(requestId);
  const opRef = db.collection('requestRoutingOperations').doc(`field-mission-decision-${eventId(actor.uid, requestId, operationId)}`);
  let outcome;
  await db.runTransaction(async (tx) => {
    if ((await tx.get(opRef)).exists) { outcome = { duplicate: true }; return; }
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('المأمورية غير موجودة.');
    const data = snap.data();
    if (data.status !== 'pending_manager' || data.currentApproverId !== actor.uid) throw new Error('ليست هذه المرحلة بانتظار قرارك.');
    const index = Number(data.currentApprovalIndex || 0);
    const route = Array.isArray(data.approvalRoute) ? data.approvalRoute.map((item) => ({ ...item })) : [];
    if (!route[index] || route[index].approverId !== actor.uid || route[index].state !== 'pending') throw new Error('مسار الموافقة غير متسق.');
    route[index] = { ...route[index], state: decision, actedAt: stamp(), comment: comment || null };
    const history = Array.isArray(data.approvalHistory) ? data.approvalHistory : [];
    history.push({ action: decision, actorId: actor.uid, actorName: actor.displayName || actor.name || 'مسؤول موافقة', comment: comment || null, at: stamp(), stage: index + 1 });
    const nextIndex = index + 1;
    const update = { approvalRoute: route, approvalHistory: history, reviewedBy: actor.uid, reviewerName: actor.displayName || actor.name || '', reviewerComment: comment || null, reviewedAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false };
    if (decision === 'rejected') {
      update.status = 'rejected'; update.currentApproverId = ''; update.currentApproverName = '';
      outcome = { employeeId: data.userId, status: 'rejected', employeeName: data.employeeName };
    } else if (nextIndex < route.length) {
      update.currentApprovalIndex = nextIndex; update.currentApproverId = route[nextIndex].approverId; update.currentApproverName = route[nextIndex].approverName; update.managerId = route[nextIndex].approverId; update.managerName = route[nextIndex].approverName;
      outcome = { employeeId: data.userId, status: 'next', next: route[nextIndex], employeeName: data.employeeName };
    } else {
      update.status = 'approved'; update.currentApproverId = ''; update.currentApproverName = ''; update.finalApprovalAt = admin.firestore.FieldValue.serverTimestamp();
      const assignmentRef = db.collection('fieldAssignments').doc(`mission-${requestId}`);
      tx.set(assignmentRef, { userId: data.userId, employeeId: data.employeeId, employeeName: data.employeeName, department: data.department, locationId: data.locationId || '', date: data.missionDate, startTime: data.startTime, endTime: data.endTime, reason: data.notes, siteName: data.siteName || '', requiresReturnToOffice: data.requiresReturnToOffice === true, requiresCheckout: data.requiresCheckout === true, status: 'active', createdBy: data.createdByHrId || '', createdAt: admin.firestore.FieldValue.serverTimestamp(), administrativeRequestId: requestId }, { merge: true });
      outcome = { employeeId: data.userId, status: 'approved', employeeName: data.employeeName };
    }
    tx.update(ref, update);
    tx.set(opRef, { operationId, requestId, kind: 'field_mission_decision', decision, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  if (!outcome || outcome.duplicate) return { requestId, duplicate: true };
  const notifications = outcome.status === 'next'
    ? [queueNotification(db, admin, { recipientId: outcome.next.approverId, type: 'field_mission_approval_turn', title: 'مأمورية بانتظار موافقتك', body: `${outcome.employeeName} لديه مأمورية تحتاج قرارك.`, data: { administrativeRequestId: requestId, route: '/manager/requests' }, key: `${requestId}:turn:${outcome.next.order}` })]
    : [queueNotification(db, admin, { recipientId: outcome.employeeId, type: outcome.status === 'approved' ? 'field_mission_approved' : 'field_mission_rejected', title: outcome.status === 'approved' ? 'تمت الموافقة على مأموريتك' : 'تم رفض المأمورية', body: outcome.status === 'approved' ? 'أصبحت المأمورية معتمدة ويمكنك تنفيذها في الموعد المحدد.' : `تم رفض المأمورية${comment ? `: ${comment}` : '.'}`, data: { administrativeRequestId: requestId, route: '/employee/requests' }, key: `${requestId}:${outcome.status}` })];
  await Promise.allSettled(notifications);
  return { requestId, status: outcome.status };
}

module.exports = {
  createFieldMission,
  decideFieldMission,
  // Exported as pure seams for the small Node contract suite.  All mutations
  // remain private to the transaction functions above.
  validateRoute,
  notificationEventId: eventId,
};
