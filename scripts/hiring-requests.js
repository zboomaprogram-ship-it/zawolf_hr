'use strict';

const crypto = require('crypto');
const { isHrOrAdmin } = require('./phase007-authorization');

const clean = (value, max = 500) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
const safeId = (value) => /^[A-Za-z0-9_-]{8,160}$/.test(String(value || ''));
const eventId = (...parts) => crypto.createHash('sha256').update(parts.join('\u001f')).digest('hex').slice(0, 40);
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(new Date());
const active = (data) => data?.isActive !== false;
const userName = (data) => clean(data?.displayName || data?.name || 'موظف', 160);
const roleText = (data) => [data?.role, data?.department, data?.departmentName, data?.position, data?.jobTitle]
  .filter(Boolean).join(' ').toLowerCase();
const isManager = (data) => ['manager', 'team_leader', 'hr_manager'].includes(String(data?.role || '').toLowerCase()) || roleText(data).includes('manager') || roleText(data).includes('مدير');
const isIt = (data) => /\bit\b|information technology|تقنية|تكنولوجيا/.test(roleText(data));
const isAccounts = (data) => /accounts?|accounting|finance|مالية|حسابات/.test(roleText(data));

function canManageHiring(actor) { return isHrOrAdmin({ ...actor, active: true }); }

async function queueNotification(db, admin, { recipientId, type, title, body, data, key }) {
  if (!recipientId) return;
  const id = `hiring-${eventId(key, recipientId)}`;
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, { notificationId: id, type, title, body, data, isRead: false, pushSent: false, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.set(db.collection('users').doc(recipientId), { unreadNotifications: admin.firestore.FieldValue.increment(1) }, { merge: true });
  });
}

async function resolveApprover(users, { kind }) {
  const candidates = users.filter(({ data }) => active(data) && (kind === 'ceo'
    ? ['CEO-100'].includes(clean(data.employeeId || data.employeeCode, 80).toUpperCase())
    : kind === 'it'
      ? (data.isHiringItApprover === true || (isManager(data) && isIt(data)))
      : (data.isHiringAccountsApprover === true || (isManager(data) && isAccounts(data)))));
  const explicit = kind === 'it'
    ? candidates.filter(({ data }) => data.isHiringItApprover === true)
    : kind === 'accounts' ? candidates.filter(({ data }) => data.isHiringAccountsApprover === true) : candidates;
  const selected = explicit.length ? explicit : candidates;
  if (selected.length !== 1) {
    const label = kind === 'ceo' ? 'CEO-100' : kind === 'it' ? 'مدير تقنية المعلومات' : 'مدير الحسابات';
    throw new Error(selected.length ? `إعداد ${label} غير واضح؛ يجب تعيين مسؤول واحد فقط.` : `لم يتم العثور على ${label} نشط.`);
  }
  const user = selected[0];
  return { id: user.id, name: userName(user.data), role: clean(user.data.role, 80) };
}

async function resolveRoute(db) {
  const snapshot = await db.collection('users').where('isActive', '==', true).limit(500).get();
  const users = snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  const [ceo, it, accounts] = await Promise.all([
    resolveApprover(users, { kind: 'ceo' }), resolveApprover(users, { kind: 'it' }), resolveApprover(users, { kind: 'accounts' }),
  ]);
  if (new Set([ceo.id, it.id, accounts.id]).size !== 3) throw new Error('مسار التعيين يحتوي على مسؤول مكرر؛ راجع إعدادات المناصب.');
  return [
    { ...ceo, labelAr: 'الرئيس التنفيذي' },
    { ...it, labelAr: 'مدير تقنية المعلومات' },
    { ...accounts, labelAr: 'مدير الحسابات' },
  ];
}

function validateCreate(body) {
  const operationId = clean(body?.operationId, 160);
  const proposedEmployeeName = clean(body?.proposedEmployeeName, 160);
  const jobTitle = clean(body?.jobTitle, 160);
  const managerId = clean(body?.managerId, 160);
  const managerName = clean(body?.managerName, 160);
  const baseMonthlySalary = Number(body?.baseMonthlySalary);
  const salaryCurrency = clean(body?.salaryCurrency || 'EGP', 8).toUpperCase();
  const assignmentDate = clean(body?.assignmentDate, 16);
  const existingEmployeeUid = clean(body?.existingEmployeeUid, 160);
  if (!safeId(operationId) || !proposedEmployeeName || !jobTitle || !safeId(managerId) || !managerName ||
      !Number.isFinite(baseMonthlySalary) || baseMonthlySalary < 0 || !/^[A-Z]{3}$/.test(salaryCurrency) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(assignmentDate) || assignmentDate < today() ||
      (existingEmployeeUid && !safeId(existingEmployeeUid))) {
    throw new Error('أكمل اسم الموظف والمسمى والمدير والراتب والعملة وتاريخ التعيين بصورة صحيحة.');
  }
  return { operationId, proposedEmployeeName, jobTitle, managerId, managerName, baseMonthlySalary, salaryCurrency, assignmentDate, existingEmployeeUid };
}

async function createHiringRequest({ db, admin, actor, body }) {
  if (!canManageHiring(actor)) throw new Error('لا تملك صلاحية إنشاء طلب تعيين.');
  const input = validateCreate(body);
  const routePeople = await resolveRoute(db);
  const [managerSnap, existingSnap] = await Promise.all([
    db.collection('users').doc(input.managerId).get(),
    input.existingEmployeeUid ? db.collection('users').doc(input.existingEmployeeUid).get() : Promise.resolve(null),
  ]);
  if (!managerSnap.exists || !active(managerSnap.data())) throw new Error('المدير المباشر المختار غير نشط.');
  if (existingSnap && (!existingSnap.exists || !active(existingSnap.data()))) throw new Error('حساب الموظف المرتبط غير نشط.');
  const operationRef = db.collection('hiringRequestOperations').doc(`create-${eventId(actor.uid, input.operationId)}`);
  const requestRef = db.collection('hiringRequests').doc(`hiring-${eventId(actor.uid, input.operationId)}`);
  const route = routePeople.map((person, index) => ({ stageId: `hiring:${requestRef.id}:${index + 1}`, order: index + 1, approverId: person.id, approverName: person.name, approverRole: person.role, labelAr: person.labelAr, state: 'pending' }));
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(operationRef);
    if (existing.exists) return;
    tx.set(requestRef, {
      requestType: 'hiring_request', status: 'pending_ceo', submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      requestedById: actor.uid, requestedByName: userName(actor), ...input,
      approvalRouteVersion: 1, approvalRoute: route, currentApprovalIndex: 0,
      currentApproverId: route[0].approverId, currentApproverName: route[0].approverName,
      approvalHistory: [{ action: 'submitted', actorId: actor.uid, actorName: userName(actor), at: new Date().toISOString() }],
    });
    tx.set(operationRef, { operationId: input.operationId, requestId: requestRef.id, actorId: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  await queueNotification(db, admin, { recipientId: route[0].approverId, type: 'hiring_request_approval_turn', title: 'طلب تعيين بانتظار قرارك', body: `${input.proposedEmployeeName} يحتاج موافقتك.`, data: { hiringRequestId: requestRef.id, route: `/hiring-requests?requestId=${requestRef.id}` }, key: `${requestRef.id}:turn:0` });
  return { requestId: requestRef.id, currentApproverId: route[0].approverId };
}

async function decideHiringRequest({ db, admin, actor, requestId, body }) {
  const operationId = clean(body?.operationId, 160); const decision = clean(body?.decision, 16); const comment = clean(body?.comment, 500);
  if (!safeId(requestId) || !safeId(operationId) || !['approved', 'rejected'].includes(decision)) throw new Error('قرار طلب التعيين غير صالح.');
  const ref = db.collection('hiringRequests').doc(requestId);
  const operationRef = db.collection('hiringRequestOperations').doc(`decision-${eventId(actor.uid, requestId, operationId)}`);
  let outcome;
  await db.runTransaction(async (tx) => {
    if ((await tx.get(operationRef)).exists) { outcome = { duplicate: true }; return; }
    const snap = await tx.get(ref); const data = snap.data() || {};
    if (!snap.exists || data.requestType !== 'hiring_request') throw new Error('طلب التعيين غير موجود.');
    if (data.currentApproverId !== actor.uid) throw new Error('هذا الطلب ليس بانتظار قرارك.');
    const route = Array.isArray(data.approvalRoute) ? data.approvalRoute.map((item) => ({ ...item })) : [];
    const index = Number(data.currentApprovalIndex || 0); const stage = route[index];
    if (!stage || stage.approverId !== actor.uid || stage.state !== 'pending') throw new Error('حالة مسار الموافقة غير صالحة.');
    route[index] = { ...stage, state: decision, actedAt: new Date().toISOString(), comment };
    const history = [...(Array.isArray(data.approvalHistory) ? data.approvalHistory : []), { action: decision, actorId: actor.uid, actorName: userName(actor), comment, at: new Date().toISOString() }];
    const nextIndex = index + 1;
    const update = { approvalRoute: route, approvalHistory: history, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (decision === 'rejected') { Object.assign(update, { status: 'rejected', currentApproverId: '', currentApproverName: '', rejectedAt: admin.firestore.FieldValue.serverTimestamp(), rejectedBy: actor.uid }); outcome = { state: 'rejected', data }; }
    else if (nextIndex < route.length) { Object.assign(update, { status: nextIndex === 1 ? 'pending_it' : 'pending_accounts', currentApprovalIndex: nextIndex, currentApproverId: route[nextIndex].approverId, currentApproverName: route[nextIndex].approverName }); outcome = { state: 'next', next: route[nextIndex], data }; }
    else { Object.assign(update, { status: 'approved', currentApproverId: '', currentApproverName: '', finalApprovalAt: admin.firestore.FieldValue.serverTimestamp(), finalApprovedBy: actor.uid }); outcome = { state: 'approved', data }; }
    tx.update(ref, update); tx.set(operationRef, { operationId, requestId, decision, actorId: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  if (outcome.duplicate) return { requestId, duplicate: true };
  const data = outcome.data; const recipients = outcome.state === 'next' ? [outcome.next.approverId] : [data.requestedById, data.existingEmployeeUid].filter(Boolean);
  await Promise.allSettled(recipients.map((recipientId) => queueNotification(db, admin, {
    recipientId, type: `hiring_request_${outcome.state}`,
    title: outcome.state === 'approved' ? 'تمت الموافقة على طلب التعيين' : outcome.state === 'rejected' ? 'تم رفض طلب التعيين' : 'طلب تعيين بانتظار قرارك',
    body: outcome.state === 'next' ? `${data.proposedEmployeeName} يحتاج موافقتك.` : `طلب تعيين ${data.proposedEmployeeName} ${outcome.state === 'approved' ? 'تمت الموافقة عليه.' : 'تم رفضه.'}`,
    data: { hiringRequestId: requestId, route: `/hiring-requests?requestId=${requestId}` }, key: `${requestId}:${outcome.state}:${recipientId}`,
  })));
  return { requestId, status: outcome.state };
}

async function listHiringRequests({ db, actor }) {
  const queries = canManageHiring(actor)
    ? [db.collection('hiringRequests').where('requestedById', '==', actor.uid).limit(100), db.collection('hiringRequests').where('currentApproverId', '==', actor.uid).limit(100)]
    : [db.collection('hiringRequests').where('currentApproverId', '==', actor.uid).limit(100), db.collection('hiringRequests').where('existingEmployeeUid', '==', actor.uid).limit(100)];
  const snaps = await Promise.all(queries.map((query) => query.get())); const byId = new Map();
  for (const snap of snaps) for (const doc of snap.docs) byId.set(doc.id, { id: doc.id, ...doc.data() });
  return [...byId.values()].sort((a, b) => String(b.assignmentDate || '').localeCompare(String(a.assignmentDate || '')));
}
module.exports = { canManageHiring, resolveRoute, createHiringRequest, decideHiringRequest, listHiringRequests };
