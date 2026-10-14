'use strict';

const { withApprovalActor } = require('./request-approval-history');

// Server-authoritative recovery for manager decisions.  Firestore rules remain
// the normal fast path; this endpoint is only used when an already-assigned
// manager receives a client permission-denied error.  It verifies the exact
// current stage from the request document before writing anything.

const MANAGER_ROLES = new Set([
  'manager', 'team_leader', 'ceo', 'coo', 'super_admin', 'admin',
]);

function clean(value, max = 500) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
}

function requestRefFor(db, collection, requestId) {
  if (!['leaves', 'permissions'].includes(collection)) {
    const error = new Error('نوع الطلب غير مدعوم.');
    error.code = 'unsupported_request';
    throw error;
  }
  if (!/^[A-Za-z0-9_-]{8,160}$/.test(requestId)) {
    const error = new Error('معرف الطلب غير صالح.');
    error.code = 'invalid_request';
    throw error;
  }
  return db.collection(collection).doc(requestId);
}

function managerIds(data) {
  const values = Array.isArray(data.managerIds) ? data.managerIds : [data.managerId];
  return [...new Set(values.map((value) => clean(value, 160)).filter(Boolean))];
}

function managerIndex(data, managers) {
  const saved = Number(data.managerApprovalIndex);
  if (Number.isInteger(saved) && saved >= 0 && saved < managers.length) return saved;
  const matched = managers.indexOf(clean(data.managerId, 160));
  return matched >= 0 ? matched : 0;
}

function error(code, message) {
  const value = new Error(message);
  value.code = code;
  return value;
}

async function queueNotification(db, admin, recipientId, id, payload) {
  if (!recipientId) return;
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, {
      notificationId: id,
      ...payload,
      isRead: false,
      pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('users').doc(recipientId), {
      unreadNotifications: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  });
}

async function activeHrIds(db) {
  const snapshot = await db.collection('users').where('role', 'in', ['hr', 'hr_admin', 'hr_manager', 'hr_staff']).limit(100).get();
  return snapshot.docs.filter((doc) => doc.data()?.isActive !== false).map((doc) => doc.id);
}

async function decideManagerRequest({ db, admin, actor, collection, requestId, body = {} }) {
  const decision = clean(body.decision, 16).toLowerCase();
  const comment = clean(body.comment, 1000);
  if (!['approve', 'reject'].includes(decision)) throw error('invalid_decision', 'القرار غير صالح.');
  const actorDoc = await db.collection('users').doc(actor.uid).get();
  const actorData = actorDoc.data() || {};
  if (!actorDoc.exists || actorData.isActive === false || !MANAGER_ROLES.has(clean(actorData.role, 64).toLowerCase())) {
    throw error('access_denied', 'لا تملك صلاحية اعتماد طلبات الموظفين.');
  }
  const requestRef = requestRefFor(db, collection, requestId);
  const policyDoc = await db.collection('publicConfig').doc('requestApproval').get();
  const requireHrAfterManager = policyDoc.data()?.requireHrAfterManagerApproval === true;
  let notification = null;
  let result;

  await db.runTransaction(async (tx) => {
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) throw error('not_found', 'الطلب غير موجود.');
    const data = requestDoc.data() || {};
    if (data.status !== 'pending_manager') {
      throw error('request_not_pending', 'الطلب لم يعد بانتظار قرار المدير.');
    }
    const managers = managerIds(data);
    const index = managerIndex(data, managers);
    const assignedId = clean(data.currentApproverId || data.managerId || managers[index], 160);
    if (!assignedId || assignedId !== actor.uid || managers[index] !== actor.uid) {
      throw error('not_current_approver', 'هذا الطلب بانتظار قرار مدير آخر.');
    }
    const actorName = clean(actorData.displayName || actorData.name || actor.displayName || 'المدير', 160);
    const history = Array.isArray(data.approvalHistory) ? data.approvalHistory : [];
    const trail = Array.isArray(data.managerApprovalTrail) ? data.managerApprovalTrail : [];
    const event = {
      stage: 'manager', status: decision === 'approve' ? 'approved' : 'rejected',
      actorId: actor.uid, actorName, comment: decision === 'reject' ? comment : '',
      at: new Date().toISOString(),
    };
    if (decision === 'reject') {
      tx.update(requestRef, {
        status: 'rejected', reviewedBy: actor.uid, reviewerName: actorName,
        reviewerComment: comment, reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        finalApproverId: actor.uid, finalApproverName: actorName,
        finalApprovalAt: admin.firestore.FieldValue.serverTimestamp(),
        currentApproverId: '', currentApproverName: '',
        approvalHistory: [...history, event],
        approvalActorIds: withApprovalActor(data, actor.uid),
      });
      notification = { recipientId: clean(data.userId, 160), kind: 'rejected', employeeName: clean(data.employeeName, 160), comment };
      result = { status: 'rejected' };
      return;
    }

    const nextIndex = index + 1;
    const nextManagerId = managers[nextIndex] || '';
    const names = Array.isArray(data.managerNames) ? data.managerNames : [];
    const nextManagerName = clean(names[nextIndex], 160);
    const requiresHr = collection === 'permissions'
      ? data.isDeductible === true || requireHrAfterManager
      : data.requiresHrApproval === true || requireHrAfterManager;
    const nextStatus = nextManagerId ? 'pending_manager' : (requiresHr ? 'pending_hr' : 'approved');
    const update = {
      status: nextStatus,
      reviewedBy: actor.uid, reviewerName: actorName,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      managerReviewedBy: actor.uid, managerReviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      managerApprovalIndex: nextManagerId ? nextIndex : Math.max(0, managers.length - 1),
      currentApprovalIndex: nextManagerId ? nextIndex : managers.length,
      managerApprovalTrail: [...trail, { managerId: actor.uid, managerName: actorName, approvedAt: new Date().toISOString() }],
      approvalHistory: [...history, event],
      approvalActorIds: withApprovalActor(data, actor.uid),
      currentApproverId: nextManagerId,
      currentApproverName: nextManagerName,
    };
    if (nextManagerId) {
      update.managerId = nextManagerId;
      update.managerName = nextManagerName;
    } else if (nextStatus === 'pending_hr') {
      update.currentApproverId = 'HR';
      update.currentApproverName = 'الموارد البشرية';
    } else {
      update.finalApproverId = actor.uid;
      update.finalApproverName = actorName;
      update.finalApprovalAt = admin.firestore.FieldValue.serverTimestamp();
    }
    tx.update(requestRef, update);
    notification = nextManagerId
      ? { recipientId: nextManagerId, kind: 'manager', employeeName: clean(data.employeeName, 160) }
      : nextStatus === 'pending_hr'
        ? { kind: 'hr', employeeName: clean(data.employeeName, 160) }
        : { recipientId: clean(data.userId, 160), kind: 'approved', employeeName: clean(data.employeeName, 160) };
    result = { status: nextStatus, nextApproverId: nextManagerId || null };
  });

  const key = `request-decision-${collection}-${requestId}-${decision}-${actor.uid}`;
  if (notification?.kind === 'manager') {
    await queueNotification(db, admin, notification.recipientId, key, {
      type: `${collection.slice(0, -1)}_pending_manager`, title: 'طلب بانتظار موافقتك',
      body: `طلب ${notification.employeeName || 'موظف'} بانتظار قرارك.`,
      data: { route: '/manager/requests', requestId, requestCollection: collection },
    });
  } else if (notification?.kind === 'hr') {
    for (const hrId of await activeHrIds(db)) {
      await queueNotification(db, admin, hrId, `${key}-${hrId}`, {
        type: `${collection.slice(0, -1)}_pending_hr`, title: 'طلب بانتظار مراجعة HR',
        body: `اكتملت موافقات المديرين على طلب ${notification.employeeName || 'موظف'}.`,
        data: { route: '/manager/requests', requestId, requestCollection: collection },
      });
    }
  } else if (notification?.recipientId) {
    await queueNotification(db, admin, notification.recipientId, key, {
      type: `${collection.slice(0, -1)}_${notification.kind}`,
      title: notification.kind === 'approved' ? 'تم قبول طلبك' : 'تم رفض طلبك',
      body: notification.kind === 'approved' ? 'تمت الموافقة على طلبك.' : `تم رفض طلبك. السبب: ${notification.comment || 'غير محدد'}`,
      data: { route: '/employee/requests', requestId, requestCollection: collection, decision: notification.kind },
    });
  }
  return result;
}

module.exports = { decideManagerRequest, managerIds, managerIndex, requestRefFor };
