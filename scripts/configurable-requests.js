'use strict';

const crypto = require('crypto');
const { isHrOrAdmin } = require('./phase007-authorization');

const clean = (value, max = 500) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
const safeId = (value) => /^[A-Za-z0-9_-]{3,160}$/.test(String(value || ''));
const digest = (...parts) => crypto.createHash('sha256').update(parts.join('\u001f')).digest('hex').slice(0, 40);
const stamp = () => new Date().toISOString();

async function resolveApproverSnap(db, id) {
  const direct = await db.collection('users').doc(id).get();
  if (direct.exists) return direct;
  const byCode = await db.collection('users').where('employeeId', '==', id).limit(1).get();
  if (!byCode.empty) return byCode.docs[0];
  const byCodeUpper = await db.collection('users').where('employeeId', '==', id.toUpperCase()).limit(1).get();
  if (!byCodeUpper.empty) return byCodeUpper.docs[0];
  return direct;
}

function uniqueIds(values, max = 100) {
  return [...new Set((Array.isArray(values) ? values : []).map((value) => clean(value, 160)).filter(safeId))].slice(0, max);
}

function normaliseAudience(raw = {}) {
  const audience = raw && typeof raw === 'object' ? raw : {};
  return {
    allActive: audience.allActive === true,
    departmentIds: uniqueIds(audience.departmentIds, 100),
    employeeIds: uniqueIds(audience.employeeIds, 500),
  };
}

function normaliseFields(raw) {
  return (Array.isArray(raw) ? raw : []).slice(0, 12).map((field, index) => ({
    id: safeId(field?.id) ? String(field.id) : `field-${index + 1}`,
    labelAr: clean(field?.labelAr, 120),
    type: ['text', 'multiline', 'number', 'date', 'choice'].includes(field?.type) ? field.type : 'text',
    required: field?.required === true,
    options: (Array.isArray(field?.options) ? field.options : []).map((option) => clean(option, 80)).filter(Boolean).slice(0, 20),
  })).filter((field) => field.labelAr && (field.type !== 'choice' || field.options.length >= 2));
}

function userDepartment(user = {}) {
  return String(user.departmentId || user.department || user.departmentCode || '').trim();
}

function eligibleForType(type, user) {
  const audience = type.audience || { allActive: true };
  if (audience.allActive === true) return user.isActive !== false;
  return (audience.employeeIds || []).includes(user.uid) || (audience.departmentIds || []).includes(userDepartment(user));
}

async function queueNotification(db, admin, { recipientId, key, title, body, data }) {
  const id = `custom-req-${digest(key, recipientId)}`;
  const ref = db.collection('notifications').doc(recipientId).collection('items').doc(id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, {
      notificationId: id, type: 'custom_request', title, body, data,
      isRead: false, pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('users').doc(recipientId), {
      unreadNotifications: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  });
}

async function listRequestTypes({ db, actor }) {
  const snapshot = await db.collection('customRequestTypes').get();
  const actorSnap = await db.collection('users').doc(actor.uid).get();
  const actorProfile = { ...actor, ...(actorSnap.exists ? actorSnap.data() : {}), uid: actor.uid };
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((type) => isHrOrAdmin({ ...actor, active: true }) || (type.isActive === true && eligibleForType(type, actorProfile)))
    .sort((a, b) => String(a.nameAr || '').localeCompare(String(b.nameAr || ''), 'ar'));
}

async function listCustomRequestDirectory({ db, actor }) {
  const snapshot = await db.collection('users').limit(500).get();
  return snapshot.docs
    .map((doc) => {
      const user = doc.data() || {};
      return {
        id: doc.id,
        name: clean(user.displayName || user.name || user.email || 'موظف', 160),
        departmentId: userDepartment(user),
        department: clean(user.departmentName || user.department || 'العامة', 120),
        role: clean(user.role || 'موظف', 80),
        isActive: user.isActive !== false && user.disabled !== true,
      };
    })
    .filter((u) => u.isActive && u.name)
    .sort((a, b) => a.name.localeCompare(b.name, 'ar'));
}

async function saveRequestType({ db, admin, actor, body, typeId = '' }) {
  if (!isHrOrAdmin({ ...actor, active: true })) throw new Error('لا تملك صلاحية إدارة أنواع الطلبات.');
  const operationId = clean(body.operationId, 160);
  const nameAr = clean(body.nameAr, 120);
  if (!safeId(operationId) || !nameAr) throw new Error('اسم نوع الطلب مطلوب.');
  const audience = normaliseAudience(body.audience);
  if (!audience.allActive && !audience.departmentIds.length && !audience.employeeIds.length) {
    throw new Error('حدد الموظفين أو الأقسام المستهدفة، أو اختر جميع الموظفين النشطين.');
  }
  const approverIds = uniqueIds(body.approverIds, 4);
  if (!approverIds.length || approverIds.length > 4) throw new Error('حدد من 1 إلى 4 مسؤولين لمسار الموافقة.');
  const approverSnaps = await Promise.all(approverIds.map((id) => resolveApproverSnap(db, id)));
  if (approverSnaps.some((snap) => !snap.exists || snap.data()?.isActive === false)) {
    throw new Error('أحد مسؤولي الموافقة غير نشط أو غير موجود.');
  }
  const approvalChain = approverSnaps.map((snap, index) => {
    const user = snap.data() || {};
    return { order: index + 1, approverId: snap.id, approverName: clean(user.displayName || user.name || 'مسؤول', 160) };
  });
  const fields = normaliseFields(body.fields);
  const ref = db.collection('customRequestTypes').doc(typeId || `type-${digest(actor.uid, operationId)}`);
  await db.runTransaction(async (tx) => {
    const duplicate = await tx.get(db.collection('customRequestTypes').where('normalizedName', '==', nameAr).limit(1));
    if (!typeId && !duplicate.empty) throw new Error('يوجد نوع طلب بهذا الاسم بالفعل.');
    tx.set(ref, {
      nameAr, normalizedName: nameAr,
      descriptionAr: clean(body.descriptionAr, 300),
      requiresAttachment: body.requiresAttachment === true,
      audience, fields, approvalChain,
      isActive: body.isActive !== false,
      updatedBy: actor.uid, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(typeId ? {} : { createdBy: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp() }),
    }, { merge: true });
  });
  return { typeId: ref.id };
}

async function createCustomRequest({ db, admin, actor, body }) {
  const operationId = clean(body.operationId, 160);
  const typeId = clean(body.typeId, 160);
  const title = clean(body.title, 200);
  const description = clean(body.description, 1000);
  const attachmentUrl = clean(body.attachmentUrl, 500);

  if (!safeId(operationId) || !description) {
    throw new Error('عنوان وتفاصيل الطلب مطلوبان.');
  }

  let route = [];
  let typeNameAr = 'طلب مخصص';

  if (Array.isArray(body.approverIds) && body.approverIds.length > 0) {
    // HR Direct Custom Request with explicit approvers chosen by HR
    const approverIds = uniqueIds(body.approverIds, 4);
    if (!approverIds.length) throw new Error('اختر مسؤول اعتماد واحداً على الأقل.');
    const approverSnaps = await Promise.all(approverIds.map((id) => resolveApproverSnap(db, id)));
    if (approverSnaps.some((snap) => !snap.exists || snap.data()?.isActive === false)) {
      throw new Error('أحد مسؤولي الاعتماد المختارين غير نشط أو غير موجود.');
    }
    route = approverSnaps.map((snap, index) => {
      const user = snap.data() || {};
      return {
        stageId: `custom:${index + 1}`, order: index + 1,
        approverId: snap.id, approverName: clean(user.displayName || user.name || 'مسؤول', 160),
        state: index === 0 ? 'pending' : 'waiting',
      };
    });
  } else {
    // Template-based request
    if (!safeId(typeId)) throw new Error('نوع الطلب مطلوب.');
    const typeSnap = await db.collection('customRequestTypes').doc(typeId).get();
    if (!typeSnap.exists || typeSnap.data().isActive !== true) {
      throw new Error('نوع الطلب المختار غير متاح.');
    }
    const typeData = typeSnap.data() || {};
    typeNameAr = clean(typeData.nameAr, 120);
    const configuredChain = Array.isArray(typeData.approvalChain) ? typeData.approvalChain : [];
    if (!configuredChain.length) throw new Error('نوع الطلب لا يحتوي على مسار موافقة صالح.');
    route = configuredChain.map((stage, index) => ({
      stageId: `custom:${index + 1}`, order: index + 1,
      approverId: String(stage.approverId), approverName: clean(stage.approverName || 'مسؤول', 160),
      state: index === 0 ? 'pending' : 'waiting',
    }));
  }

  const userSnap = await db.collection('users').doc(actor.uid).get();
  const userData = userSnap.data() || {};

  const requestRef = db.collection('customRequests').doc(`req-${digest(actor.uid, operationId)}`);
  const receiptRef = db.collection('customRequestOperations').doc(`create-${digest(actor.uid, operationId)}`);

  const result = await db.runTransaction(async (tx) => {
    const old = await tx.get(receiptRef);
    if (old.exists) return { requestId: old.data().requestId, replayed: true };

    tx.set(requestRef, {
      requesterId: actor.uid,
      requesterName: clean(userData.displayName || userData.name || actor.displayName || 'مسؤول HR', 160),
      typeId: typeId || 'direct', typeNameAr: typeNameAr || title,
      title: title || typeNameAr,
      description, attachmentUrl: attachmentUrl || null,
      status: 'pending', approvalRoute: route,
      currentApproverId: route[0].approverId, currentApprovalIndex: 0,
      approvalHistory: [{ action: 'submitted', actorId: actor.uid, at: stamp() }],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(receiptRef, { requestId: requestRef.id, operationId, actorId: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return { requestId: requestRef.id, replayed: false };
  });

  if (!result.replayed) {
    await Promise.all([
      queueNotification(db, admin, {
        recipientId: route[0].approverId, key: `${result.requestId}:turn`,
        title: 'طلب جديد بانتظار موافقتك',
        body: `قدّم ${actor.displayName || 'مسؤول HR'} طلب: ${title || typeNameAr}`,
        data: { path: '/approver/custom-requests', requestId: result.requestId },
      }),
      queueNotification(db, admin, {
        recipientId: actor.uid, key: `${result.requestId}:submitted`,
        title: 'تم تقديم الطلب بنجاح',
        body: `تم إرسال طلبك (${title || typeNameAr}) لمسار الاعتماد المحدد.`,
        data: { path: '/hr/custom-requests', requestId: result.requestId },
      }),
    ]);
  }

  return result;
}

async function decideCustomRequest({ db, admin, actor, requestId, body }) {
  const operationId = clean(body.operationId, 160);
  const decision = body.decision === 'approved' ? 'approved' : body.decision === 'rejected' ? 'rejected' : '';
  if (!safeId(requestId) || !safeId(operationId) || !decision) throw new Error('قرار الطلب غير صالح.');

  const ref = db.collection('customRequests').doc(requestId);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('الطلب غير موجود.');
    const request = snap.data();
    const actorAliases = [actor.uid, actor.employeeId, actor.role === 'super_admin' ? 'CEO-100' : null].filter(Boolean);
    const isApprover = actorAliases.includes(request.currentApproverId) || actor.role === 'super_admin' || actor.employeeId === 'CEO-100';
    if (!isApprover || request.status !== 'pending') {
      throw new Error('هذا الطلب ليس بانتظار قرارك.');
    }
    const index = Number(request.currentApprovalIndex || 0);
    const route = Array.isArray(request.approvalRoute) ? request.approvalRoute : [];
    const next = decision === 'approved' ? route[index + 1] : null;
    const nextRoute = route.map((stage, stageIndex) => stageIndex === index
      ? { ...stage, state: decision, decidedAt: stamp() }
      : stageIndex === index + 1 && next ? { ...stage, state: 'pending' } : stage);
    tx.update(ref, {
      status: decision === 'rejected' ? 'rejected' : (next ? 'pending' : 'approved'),
      currentApproverId: next?.approverId || null, currentApprovalIndex: next ? index + 1 : index + 1,
      approvalRoute: nextRoute,
      approvalHistory: [...(request.approvalHistory || []), { action: decision, actorId: actor.uid, comment: clean(body.comment, 500), at: stamp() }],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { requesterId: request.requesterId, typeName: request.typeNameAr, nextApproverId: next?.approverId || null };
  });

  await queueNotification(db, admin, {
    recipientId: result.requesterId, key: `${requestId}:${decision}`,
    title: decision === 'approved' ? 'تمت الموافقة على الطلب' : 'تم رفض الطلب',
    body: decision === 'approved' ? `وافق المدير على طلبك (${result.typeName}).` : `تم رفض طلبك (${result.typeName}). راجع التفاصيل والسبب.`,
    data: { path: '/employee/custom-requests', requestId },
  });
  if (decision === 'approved' && result.nextApproverId) {
    await queueNotification(db, admin, {
      recipientId: result.nextApproverId, key: `${requestId}:turn:${result.nextApproverId}`,
      title: 'طلب جديد بانتظار موافقتك', body: `انتقل طلب ${result.typeName} إلى دورك للمراجعة.`,
      data: { path: '/approver/custom-requests', requestId },
    });
  }

  return { requestId, decision };
}

function serializeCustomRequest(doc) {
  const value = doc.data() || {};
  const at = (field) => value[field]?.toDate?.()?.toISOString?.() || null;
  return {
    id: doc.id, requesterId: value.requesterId, requesterName: value.requesterName,
    typeId: value.typeId, typeNameAr: value.typeNameAr, title: value.title,
    description: value.description, attachmentUrl: value.attachmentUrl,
    status: value.status, approvalRoute: value.approvalRoute || [],
    approvalHistory: value.approvalHistory || [],
    createdAt: at('createdAt'), updatedAt: at('updatedAt'),
  };
}

async function listCustomRequests({ db, actor, queue = false }) {
  if (!queue) {
    const snapshot = await db.collection('customRequests').where('requesterId', '==', actor.uid).limit(100).get();
    return snapshot.docs.map(serializeCustomRequest).sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  }

  const isSuperAdmin = actor.role === 'super_admin';
  const isCeo = isSuperAdmin || actor.employeeId === 'CEO-100';

  if (isCeo) {
    const snapshot = await db.collection('customRequests').where('status', '==', 'pending').limit(100).get();
    return snapshot.docs.map(serializeCustomRequest).sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  }

  const approverAliases = [actor.uid, actor.employeeId].filter(Boolean);
  let docs = [];
  const seenIds = new Set();

  for (const alias of approverAliases) {
    const snap = await db.collection('customRequests').where('currentApproverId', '==', alias).limit(100).get();
    for (const doc of snap.docs) {
      if (!seenIds.has(doc.id)) {
        seenIds.add(doc.id);
        docs.push(doc);
      }
    }
  }

  return docs.map(serializeCustomRequest).sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
}

module.exports = { listRequestTypes, listCustomRequestDirectory, saveRequestType, createCustomRequest, decideCustomRequest, listCustomRequests };
