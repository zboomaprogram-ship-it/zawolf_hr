'use strict';

const CAIRO_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
});

function cairoDateKey(date = new Date()) { return CAIRO_FORMATTER.format(date); }
function text(value) { return typeof value === 'string' ? value.trim() : ''; }
function isIsoDate(value) { return /^\d{4}-\d{2}-\d{2}$/.test(value); }
function error(message, code = 'invalid_request') { const value = new Error(message); value.code = code; return value; }
function roleKey(value) { return text(value).toLowerCase().replace(/[\s-]+/g, '_'); }
function isHrOrSuperAdmin(actor) {
  const role = roleKey(actor?.role);
  if (['super_admin', 'admin', 'administrator', 'hr', 'hr_admin', 'hr_manager'].includes(role)) return true;
  const scope = `${actor?.department || ''} ${actor?.position || ''} ${actor?.jobTitle || ''}`.toLowerCase();
  return scope.includes('human resource') || scope.includes('الموارد البشرية') || scope.includes('موارد بشرية') || scope.includes('شؤون العاملين');
}
function safeGrant(data = {}) {
  return {
    employeeId: text(data.employeeId), employeeName: text(data.employeeName), employeeCode: text(data.employeeCode),
    scope: data.scope === 'permanent' ? 'permanent' : 'period',
    startDate: text(data.startDate), endDate: data.endDate == null ? null : text(data.endDate),
    status: text(data.status), revision: Number(data.revision || 0), note: text(data.note) || null,
    allowAnyLocation: data.allowAnyLocation === true,
    grantedById: text(data.grantedById), grantedByName: text(data.grantedByName),
    grantedAt: data.grantedAt || null, revokedAt: data.revokedAt || null,
  };
}
function validateGrantInput(input) {
  const employeeId = text(input.employeeId);
  const scope = input.scope === 'permanent' ? 'permanent' : input.scope === 'period' ? 'period' : '';
  if (!employeeId || !scope) throw error('بيانات تصريح الحضور عبر الويب غير مكتملة.');
  const note = text(input.note);
  const allowAnyLocation = input.allowAnyLocation === true;
  if (note.length > 500) throw error('ملاحظة التصريح طويلة جداً.');
  if (scope === 'permanent') return { employeeId, scope, startDate: null, endDate: null, note: note || null, allowAnyLocation };
  const startDate = text(input.startDate); const endDate = text(input.endDate);
  if (!isIsoDate(startDate) || !isIsoDate(endDate) || endDate < startDate) throw error('حدد فترة صحيحة لتصريح الحضور عبر الويب.');
  const days = Math.round((Date.parse(`${endDate}T00:00:00Z`) - Date.parse(`${startDate}T00:00:00Z`)) / 86400000) + 1;
  if (days > 366) throw error('الحد الأقصى لفترة التصريح هو 366 يوماً.');
  return { employeeId, scope, startDate, endDate, note: note || null, allowAnyLocation };
}
function effective(data, today = cairoDateKey()) {
  if (!data || data.status !== 'active') return false;
  if (data.scope === 'permanent') return true;
  return isIsoDate(text(data.startDate)) && isIsoDate(text(data.endDate)) && data.startDate <= today && today <= data.endDate;
}
function operationRef(db, actorId, operationId) {
  const normalized = text(operationId).replace(/[^A-Za-z0-9_-]/g, '').slice(0, 96);
  if (!normalized) throw error('معرّف العملية مطلوب لإتمام التصريح.');
  return db.collection('webAttendanceAccessOperations').doc(`${actorId}_${normalized}`);
}

async function getMyWebAttendanceAccess({ admin, actor }) {
  const snap = await admin.firestore().collection('webAttendanceAccessGrants').doc(actor.uid).get();
  const grant = snap.exists ? safeGrant(snap.data()) : null;
  return { eligible: effective(grant), grant: grant && effective(grant) ? grant : null, today: cairoDateKey() };
}

async function listWebAttendanceAccessGrants({ admin, actor, limit = 200 }) {
  if (!isHrOrSuperAdmin(actor)) throw error('لا تملك صلاحية إدارة تصاريح الحضور عبر الويب.', 'not_authorized');
  const snap = await admin.firestore().collection('webAttendanceAccessGrants').orderBy('updatedAt', 'desc').limit(Math.min(200, Math.max(1, Number(limit) || 100))).get();
  const today = cairoDateKey();
  return { grants: snap.docs.map(doc => ({ id: doc.id, ...safeGrant(doc.data()), eligible: effective(doc.data(), today) })), today };
}

async function saveWebAttendanceAccessGrant({ admin, actor, input, operationId }) {
  if (!isHrOrSuperAdmin(actor)) throw error('لا تملك صلاحية إدارة تصاريح الحضور عبر الويب.', 'not_authorized');
  const grantInput = validateGrantInput(input);
  const db = admin.firestore();
  const currentRef = db.collection('webAttendanceAccessGrants').doc(grantInput.employeeId);
  const opRef = operationRef(db, actor.uid, operationId);
  const auditRef = db.collection('webAttendanceAccessGrantAudit').doc();
  let result;
  await db.runTransaction(async transaction => {
    const [employeeSnap, currentSnap, operationSnap] = await Promise.all([
      transaction.get(db.collection('users').doc(grantInput.employeeId)), transaction.get(currentRef), transaction.get(opRef),
    ]);
    if (operationSnap.exists) { result = operationSnap.data().result; return; }
    if (!employeeSnap.exists || employeeSnap.data()?.isActive === false) throw error('لا يمكن منح تصريح لحساب موظف غير نشط.', 'employee_inactive');
    const employee = employeeSnap.data() || {}; const previous = currentSnap.exists ? safeGrant(currentSnap.data()) : null;
    const next = {
      employeeId: grantInput.employeeId,
      employeeName: text(employee.displayName || employee.name),
      employeeCode: text(employee.employeeId || employee.employeeCode),
      scope: grantInput.scope, startDate: grantInput.startDate, endDate: grantInput.endDate,
      allowAnyLocation: grantInput.allowAnyLocation,
      status: 'active', note: grantInput.note,
      revision: Number(previous?.revision || 0) + 1,
      grantedById: actor.uid, grantedByName: text(actor.displayName || actor.name),
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
      revokedById: null, revokedAt: null, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    result = { grant: { ...safeGrant(next), eligible: effective(next) } };
    transaction.set(currentRef, next);
    transaction.set(auditRef, { eventType: previous ? 'updated' : 'granted', employeeId: grantInput.employeeId, actorId: actor.uid, operationId: text(operationId), before: previous, after: safeGrant(next), createdAt: admin.firestore.FieldValue.serverTimestamp() });
    transaction.set(opRef, { result, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  console.info('Web attendance access grant saved:', { actorId: actor.uid, employeeId: grantInput.employeeId, scope: grantInput.scope, allowAnyLocation: grantInput.allowAnyLocation });
  return result;
}

async function revokeWebAttendanceAccessGrant({ admin, actor, employeeId, operationId, note }) {
  if (!isHrOrSuperAdmin(actor)) throw error('لا تملك صلاحية إدارة تصاريح الحضور عبر الويب.', 'not_authorized');
  const targetId = text(employeeId); if (!targetId) throw error('الموظف مطلوب.');
  const db = admin.firestore(); const currentRef = db.collection('webAttendanceAccessGrants').doc(targetId); const opRef = operationRef(db, actor.uid, operationId); const auditRef = db.collection('webAttendanceAccessGrantAudit').doc(); let result;
  await db.runTransaction(async transaction => {
    const [currentSnap, operationSnap] = await Promise.all([transaction.get(currentRef), transaction.get(opRef)]);
    if (operationSnap.exists) { result = operationSnap.data().result; return; }
    if (!currentSnap.exists) throw error('لا يوجد تصريح حضور عبر الويب لهذا الموظف.', 'not_found');
    const previous = safeGrant(currentSnap.data()); const next = { ...previous, status: 'revoked', revision: previous.revision + 1, revokedById: actor.uid, revokedAt: admin.firestore.FieldValue.serverTimestamp(), note: text(note) || previous.note, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    result = { grant: { ...safeGrant(next), eligible: false } };
    transaction.set(currentRef, next, { merge: false });
    transaction.set(auditRef, { eventType: 'revoked', employeeId: targetId, actorId: actor.uid, operationId: text(operationId), before: previous, after: safeGrant(next), createdAt: admin.firestore.FieldValue.serverTimestamp() });
    transaction.set(opRef, { result, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  console.info('Web attendance access grant revoked:', { actorId: actor.uid, employeeId: targetId });
  return result;
}

async function assertWebAttendanceAccess({ admin, actor }) {
  const result = await getMyWebAttendanceAccess({ admin, actor });
  if (!result.eligible) throw error('لا يوجد تصريح نشط لتسجيل الحضور عبر الويب. استخدم تطبيق الجوال أو تواصل مع HR.', 'web_attendance_not_authorized');
  return result.grant;
}
module.exports = { getMyWebAttendanceAccess, listWebAttendanceAccessGrants, saveWebAttendanceAccessGrant, revokeWebAttendanceAccessGrant, assertWebAttendanceAccess, isHrOrSuperAdmin, effective, validateGrantInput };
