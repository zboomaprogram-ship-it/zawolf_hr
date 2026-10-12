'use strict';

const crypto = require('node:crypto');

const REQUEST_COLLECTIONS = Object.freeze([
  'leaves',
  'permissions',
  'advances',
  'administrativeRequests',
  'attendanceCorrectionRequests',
  'resignations',
  'employeeDeletionRequests',
  'complaints',
  'customRequests',
  'meetingRequests',
  'hiringRequests',
]);

const WATCHED_STATUSES = Object.freeze([
  'new',
  'pending',
  'pending_team_leader',
  'pending_manager',
  'pending_hr',
  'pending_hr_manager',
  'pending_super_admin',
  'pending_ceo',
  'pending_coo',
  'pending_it',
  'pending_accounts',
  'approved',
  'accepted',
  'rejected',
  'cancelled',
  'canceled',
  'closed',
  'paid',
]);

const TERMINAL_STATUSES = new Set([
  'approved', 'accepted', 'rejected', 'cancelled', 'canceled', 'closed', 'paid',
]);

const ROLE_MARKERS = new Map([
  ['HR', 'hr'],
  ['ACCOUNTING', 'accounting'],
  ['ACCOUNTS', 'accounting'],
  ['IT', 'it'],
  ['CEO', 'ceo'],
  ['CEO-100', 'ceo'],
  ['COO', 'coo'],
  ['COO-1300', 'coo'],
  ['SUPER_ADMIN', 'super_admin'],
]);

const REQUEST_ID_FIELDS = Object.freeze({
  leaves: ['leaveId', 'requestId'],
  permissions: ['permissionId', 'requestId'],
  advances: ['advanceId', 'requestId'],
  administrativeRequests: ['administrativeRequestId', 'requestId'],
  attendanceCorrectionRequests: ['attendanceCorrectionRequestId', 'requestId'],
  resignations: ['resignationId', 'requestId'],
  employeeDeletionRequests: ['requestId'],
  complaints: ['complaintId', 'requestId'],
  customRequests: ['customRequestId', 'requestId'],
  meetingRequests: ['meetingRequestId', 'requestId'],
  hiringRequests: ['hiringRequestId', 'requestId'],
});

const clean = (value) => String(value || '').trim();
const upper = (value) => clean(value).toUpperCase();
const unique = (values) => [...new Set(values.map(clean).filter(Boolean))];

function currentRouteStage(request = {}) {
  const route = Array.isArray(request.approvalRoute) ? request.approvalRoute : [];
  const index = Math.max(0, Number(request.currentApprovalIndex ?? request.managerApprovalIndex ?? 0));
  return route[index] && typeof route[index] === 'object' ? route[index] : null;
}

function employeeIdentity(request = {}) {
  return unique([
    request.userId,
    request.employeeUid,
    request.employeeUserId,
    request.requesterId,
    request.requestedById,
    request.requestedBy,
    request.createdBy,
  ])[0] || '';
}

function roleFromApproverType(value) {
  const type = clean(value).toLowerCase();
  if (['hr', 'hr_pool', 'human_resources'].includes(type)) return 'hr';
  if (['accounting', 'accounts', 'finance'].includes(type)) return 'accounting';
  if (['it', 'information_technology'].includes(type)) return 'it';
  if (type === 'ceo') return 'ceo';
  if (type === 'coo') return 'coo';
  if (['admin', 'super_admin'].includes(type)) return 'super_admin';
  return '';
}

function approvalAudience(request = {}) {
  const status = clean(request.status).toLowerCase();
  if (TERMINAL_STATUSES.has(status)) {
    const id = employeeIdentity(request);
    return id ? { kind: 'employee', ids: [id], status } : { kind: 'none', ids: [], status };
  }

  const stage = currentRouteStage(request);
  const stageId = clean(stage?.approverId || stage?.specificUserId);
  const stageRole = roleFromApproverType(stage?.approverType || stage?.type);
  const stageDepartment = clean(stage?.department || stage?.departmentName);
  if (stageId && !ROLE_MARKERS.has(upper(stageId))) {
    return { kind: 'ids', ids: [stageId], status };
  }
  if (stageRole) return { kind: 'role', role: stageRole, ids: [], status };
  if (stageDepartment) {
    return { kind: 'department', department: stageDepartment, ids: [], status };
  }

  const currentApprover = clean(request.currentApproverId);
  if (currentApprover && !ROLE_MARKERS.has(upper(currentApprover))) {
    return { kind: 'ids', ids: [currentApprover], status };
  }
  const markerRole = ROLE_MARKERS.get(upper(currentApprover));
  if (markerRole) return { kind: 'role', role: markerRole, ids: [], status };

  if (status === 'pending_manager') {
    const managers = Array.isArray(request.managerIds) ? request.managerIds : [];
    const index = Math.max(0, Number(request.managerApprovalIndex || 0));
    const current = clean(request.managerId || managers[index]);
    return current ? { kind: 'ids', ids: [current], status } : { kind: 'none', ids: [], status };
  }
  if (status === 'pending_team_leader') {
    const teamLeader = clean(request.teamLeaderId || request.managerId);
    return teamLeader ? { kind: 'ids', ids: [teamLeader], status } : { kind: 'none', ids: [], status };
  }
  if (status === 'pending_hr' || status === 'pending_hr_manager' || status === 'new') {
    return { kind: 'role', role: 'hr', ids: [], status };
  }
  if (status === 'pending_super_admin') return { kind: 'role', role: 'super_admin', ids: [], status };
  if (status === 'pending_ceo') {
    const ceo = clean(request.ceoId);
    return ceo && !ROLE_MARKERS.has(upper(ceo))
      ? { kind: 'ids', ids: [ceo], status }
      : { kind: 'role', role: 'ceo', ids: [], status };
  }
  if (status === 'pending_coo') return { kind: 'role', role: 'coo', ids: [], status };
  if (status === 'pending_it') return { kind: 'role', role: 'it', ids: [], status };
  if (status === 'pending_accounts') return { kind: 'role', role: 'accounting', ids: [], status };
  if (status === 'pending') {
    const manager = clean(request.managerId);
    return manager ? { kind: 'ids', ids: [manager], status } : { kind: 'role', role: 'hr', ids: [], status };
  }
  return { kind: 'none', ids: [], status };
}

function userAliases(user = {}) {
  return unique([user.uid, user.id, user.employeeId, user.employeeCode]).map(upper);
}

function userMatchesRole(user = {}, role) {
  const normalizedRole = clean(user.role).toLowerCase();
  const department = clean(user.department || user.departmentName).toLowerCase();
  const position = clean(user.position || user.jobTitle).toLowerCase();
  const code = upper(user.employeeId || user.employeeCode);
  if (role === 'hr') {
    return ['hr', 'hr_admin', 'hr_manager', 'hr_specialist', 'hr_officer', 'hr_staff'].includes(normalizedRole) ||
      user.isHr === true || department.includes('human resource') || department.includes('الموارد البشرية');
  }
  if (role === 'super_admin') return normalizedRole === 'super_admin';
  if (role === 'ceo') return normalizedRole === 'ceo' || clean(user.executiveRole).toLowerCase() === 'ceo' || code === 'CEO-100';
  if (role === 'coo') return normalizedRole === 'coo' || clean(user.executiveRole).toLowerCase() === 'coo' || code === 'COO-1300';
  if (role === 'accounting') {
    return user.isAdvanceAccountsApprover === true || normalizedRole === 'accountant' ||
      /account|finance|حساب|مالية/.test(`${department} ${position}`);
  }
  if (role === 'it') return /(^|\s)it(\s|$)|information technology|تقنية|تكنولوجيا/.test(`${department} ${position}`);
  return false;
}

function resolveAudienceUsers(audience, users, request = {}) {
  const requester = upper(employeeIdentity(request));
  const matches = users.filter((user) => {
    if (user.isActive === false || user.disabled === true) return false;
    if (audience.kind === 'employee') {
      return userAliases(user).includes(upper(audience.ids[0]));
    }
    // Requesters never receive an actionable approval notification for their
    // own request, even if their profile also carries a manager/HR role.
    if (requester && userAliases(user).includes(requester)) return false;
    if (audience.kind === 'ids') {
      const expected = new Set(audience.ids.map(upper));
      return userAliases(user).some((alias) => expected.has(alias));
    }
    if (audience.kind === 'role') return userMatchesRole(user, audience.role);
    if (audience.kind === 'department') {
      return upper(user.department || user.departmentName) === upper(audience.department);
    }
    return false;
  });
  return unique(matches.map((user) => user.uid || user.id));
}

function notificationIdentity({ collection, requestId, request, recipientId }) {
  const status = clean(request.status).toLowerCase() || 'unknown';
  const index = Math.max(0, Number(request.currentApprovalIndex ?? request.managerApprovalIndex ?? 0));
  const digest = crypto.createHash('sha256')
    .update([collection, requestId, status, index, recipientId].join('\u001f'))
    .digest('hex').slice(0, 40);
  return `request-stage-${digest}`;
}

function requestRoute(collection, requestId, employee) {
  if (employee) return `/employee/requests?requestId=${encodeURIComponent(requestId)}`;
  const categories = {
    leaves: 'leaves', permissions: 'permissions', advances: 'advances',
    administrativeRequests: 'administrative', attendanceCorrectionRequests: 'attendance_corrections',
    resignations: 'resignations', employeeDeletionRequests: 'administrative', complaints: 'complaints',
    customRequests: 'custom', meetingRequests: 'meetings', hiringRequests: 'hiring',
  };
  return `/manager/requests?category=${categories[collection] || 'all'}&requestId=${encodeURIComponent(requestId)}`;
}

function notificationFor({ collection, requestId, request, recipientId, audience }) {
  const employee = audience.kind === 'employee';
  const employeeName = clean(request.employeeName || request.requesterName || request.proposedEmployeeName || 'موظف');
  const status = clean(request.status).toLowerCase();
  const approved = ['approved', 'accepted', 'paid', 'closed'].includes(status);
  return {
    notificationId: notificationIdentity({ collection, requestId, request, recipientId }),
    type: employee ? 'request_status_updated' : 'request_approval_turn',
    title: employee
      ? (approved ? 'تم اعتماد طلبك' : status.startsWith('cancel') ? 'تم إلغاء طلبك' : 'تم رفض طلبك')
      : 'طلب بانتظار قرارك',
    body: employee
      ? (approved ? 'تم اعتماد الطلب. يمكنك فتح سجل الطلبات لعرض التفاصيل.' : 'تم تحديث الطلب. افتح سجل الطلبات لعرض القرار والتفاصيل.')
      : `${employeeName}: يوجد طلب يحتاج قرارك الآن.`,
    data: {
      route: requestRoute(collection, requestId, employee),
      requestCollection: collection,
      requestId,
      actionRequired: employee ? 'view_request_result' : 'review_request',
    },
    isRead: false,
    pushSent: false,
  };
}

async function loadActiveUsers(db) {
  const snapshot = await db.collection('users').where('isActive', '==', true).limit(500).get();
  return snapshot.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));
}

async function queueOnce({ db, admin, recipientId, notification }) {
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(notification.notificationId);
  return db.runTransaction(async (transaction) => {
    if ((await transaction.get(ref)).exists) return false;
    transaction.create(ref, {
      ...notification,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.set(db.collection('users').doc(recipientId), {
      unreadNotifications: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
    return true;
  });
}

async function hasExistingActionNotification({ db, collection, requestId, recipientId }) {
  const items = db.collection('notifications').doc(recipientId).collection('items');
  for (const field of REQUEST_ID_FIELDS[collection] || ['requestId']) {
    const existing = await items.where(`data.${field}`, '==', requestId).limit(1).get();
    if (!existing.empty) return true;
  }
  return false;
}

async function reconcileRequestNotification({ db, admin, collection, requestId, request, users }) {
  const audience = approvalAudience(request);
  if (audience.kind === 'none') return { found: 0, created: 0 };
  if (audience.kind === 'employee') {
    const value = request.finalApprovalAt || request.reviewedAt || request.updatedAt || request.cancelledAt || request.submittedAt;
    const occurredAt = value?.toDate?.() || (value instanceof Date ? value : null);
    // A listener restart must not notify employees about years of historical
    // requests. Recent terminal transitions are recovered for two days.
    if (!occurredAt || Date.now() - occurredAt.getTime() > 2 * 24 * 60 * 60 * 1000) {
      return { found: 0, created: 0 };
    }
  }
  const directory = users || await loadActiveUsers(db);
  const recipients = resolveAudienceUsers(audience, directory, request);
  let created = 0;
  for (const recipientId of recipients) {
    // Current mobile builds still attempt the first notification directly
    // after committing the request. Avoid producing a second card when that
    // legacy write succeeded; this server path repairs only missing delivery.
    if (audience.kind !== 'employee' && await hasExistingActionNotification({
      db, collection, requestId, recipientId,
    })) continue;
    const notification = notificationFor({ collection, requestId, request, recipientId, audience });
    if (await queueOnce({ db, admin, recipientId, notification })) created += 1;
  }
  return { found: recipients.length, created };
}

function watchRequestNotifications({ db, admin, onQueued = () => {}, onError = () => {} }) {
  let cachedUsers = [];
  let usersLoadedAt = 0;
  const directory = async () => {
    if (!cachedUsers.length || Date.now() - usersLoadedAt > 60_000) {
      cachedUsers = await loadActiveUsers(db);
      usersLoadedAt = Date.now();
    }
    return cachedUsers;
  };
  const pendingTimers = new Set();
  const unsubscribers = REQUEST_COLLECTIONS.map((collection) => db.collection(collection)
    .where('status', 'in', WATCHED_STATUSES)
    .limit(100)
    .onSnapshot((snapshot) => {
      for (const change of snapshot.docChanges()) {
        if (!['added', 'modified'].includes(change.type)) continue;
        const timer = setTimeout(() => {
          pendingTimers.delete(timer);
          void directory()
            .then((users) => reconcileRequestNotification({
              db, admin, collection, requestId: change.doc.id,
              request: change.doc.data() || {}, users,
            }))
            .then((result) => { if (result.created > 0) onQueued(result.created); })
            .catch(onError);
        }, 2000);
        pendingTimers.add(timer);
      }
    }, onError));
  return () => {
    for (const timer of pendingTimers) clearTimeout(timer);
    pendingTimers.clear();
    unsubscribers.forEach((unsubscribe) => unsubscribe?.());
  };
}

module.exports = {
  REQUEST_COLLECTIONS,
  WATCHED_STATUSES,
  approvalAudience,
  currentRouteStage,
  employeeIdentity,
  hasExistingActionNotification,
  notificationFor,
  notificationIdentity,
  resolveAudienceUsers,
  reconcileRequestNotification,
  userMatchesRole,
  watchRequestNotifications,
};
