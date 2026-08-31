const crypto = require('node:crypto');

const MAX_BULK_EMPLOYEES = 100;
const CAIRO_DATE_TIME = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Africa/Cairo',
  year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
});

function assignmentError(messageAr, code = 'invalid_request', status = 400) {
  const error = new Error(messageAr);
  error.code = code;
  error.status = status;
  error.messageAr = messageAr;
  return error;
}

function assignmentId(employeeUid, locationId) {
  return `${String(employeeUid).trim()}_${String(locationId).trim()}`;
}

function asDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function isEffective(assignment, eventTime) {
  if (assignment.status !== 'active' && assignment.isActive !== true) return false;
  const start = asDate(assignment.effectiveFrom);
  const end = asDate(assignment.effectiveTo);
  return (!start || eventTime >= start) && (!end || eventTime <= end);
}

function radians(value) { return Number(value) * Math.PI / 180; }

function haversineMeters(latitudeA, longitudeA, latitudeB, longitudeB) {
  const deltaLat = radians(latitudeB - latitudeA);
  const deltaLng = radians(longitudeB - longitudeA);
  const latA = radians(latitudeA);
  const latB = radians(latitudeB);
  const haversine = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(latA) * Math.cos(latB) * Math.sin(deltaLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

function locationCoordinates(location) {
  const latitude = Number(location.latitude ?? location.lat ?? location.position?.latitude);
  const longitude = Number(location.longitude ?? location.lng ?? location.position?.longitude);
  const radius = Number(location.geofenceRadiusMeters ?? location.radius ?? location.radiusMeters);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || !Number.isFinite(radius) || radius <= 0) {
    throw assignmentError('إعدادات نطاق موقع الحضور غير مكتملة.', 'inactive_location', 409);
  }
  return { latitude, longitude, radius };
}

async function loadMultiLocationFlag(db, actorUid = '') {
  const snap = await db.collection('publicConfig').doc('appSecurity').get();
  const config = snap.exists ? (snap.data() || {}) : {};
  const remote = config.attendance_multi_location_v1;
  if (remote && typeof remote === 'object') {
    if (remote.enabled !== true) return false;
    if (remote.everyone === true) return true;
    return Array.isArray(remote.actorIds) &&
      remote.actorIds.map(String).includes(String(actorUid));
  }
  return remote === true || config.attendanceMultiLocationEnabled === true;
}

async function validateAssignedLocation({ db, actorUid, rawAction, eventTime }) {
  const locationId = String(rawAction?.locationId || '').trim();
  const suppliedAssignmentId = String(rawAction?.assignmentId || '').trim();
  const expectedAssignmentId = assignmentId(actorUid, locationId);
  if (!locationId || suppliedAssignmentId !== expectedAssignmentId) {
    throw assignmentError('هذا الموقع غير مسند إلى حسابك.', 'no_assignment', 403);
  }

  const [assignmentSnap, locationSnap] = await Promise.all([
    db.collection('attendanceLocationAssignments').doc(expectedAssignmentId).get(),
    db.collection('locations').doc(locationId).get(),
  ]);
  if (!assignmentSnap.exists) {
    throw assignmentError('لا يوجد موقع حضور مسند صالح لهذا الحساب.', 'no_assignment', 403);
  }
  const assignment = assignmentSnap.data() || {};
  if (assignment.employeeUid !== actorUid || assignment.locationId !== locationId || !isEffective(assignment, eventTime)) {
    throw assignmentError('انتهى أو تغير إسناد موقع الحضور. حدّث المواقع ثم أعد المحاولة.', 'assignment_changed', 409);
  }
  const version = Number(assignment.version || 1);
  if (Number(rawAction.assignmentVersion) !== version) {
    throw assignmentError('تم تحديث مواقع الحضور المسندة. حدّث الصفحة ثم أعد المحاولة.', 'assignment_changed', 409);
  }
  if (!locationSnap.exists || locationSnap.data()?.isActive === false) {
    throw assignmentError('موقع الحضور غير نشط حالياً.', 'inactive_location', 409);
  }
  const location = locationSnap.data() || {};
  const coordinates = locationCoordinates(location);
  const distanceMeters = haversineMeters(
    Number(rawAction.latitude), Number(rawAction.longitude),
    coordinates.latitude, coordinates.longitude,
  );
  const accuracyMeters = Math.max(0, Number(rawAction.accuracyMeters) || 0);
  const allowedRadiusMeters = coordinates.radius + Math.min(accuracyMeters, 12);
  if (distanceMeters > allowedRadiusMeters) {
    throw assignmentError('أنت خارج نطاق مواقع الحضور المسندة إليك.', 'outside_range', 409);
  }
  return {
    assignmentId: expectedAssignmentId,
    assignmentVersion: version,
    locationId,
    locationName: String(location.name || assignment.locationName || ''),
    locationLatitude: coordinates.latitude,
    locationLongitude: coordinates.longitude,
    distanceMeters,
    configuredRadiusMeters: coordinates.radius,
    allowedRadiusMeters,
    latitude: Number(rawAction.latitude),
    longitude: Number(rawAction.longitude),
    accuracyMeters,
    validatedAt: new Date(),
  };
}

function canManageAttendanceLocations(actor = {}) {
  const roles = new Set(['super_admin', 'admin', 'hr', 'hr_admin', 'hr_manager']);
  const capabilities = Array.isArray(actor.capabilities) ? actor.capabilities : [];
  return roles.has(actor.role) || capabilities.includes('attendance_location_manage');
}

function requireManager(actor) {
  if (!canManageAttendanceLocations(actor)) {
    throw assignmentError('لا تملك صلاحية إدارة مواقع حضور الموظفين.', 'not_authorized', 403);
  }
}

function normalizePreviewInput(raw = {}) {
  const employeeUids = [...new Set((raw.employeeUids || []).map(String).map((value) => value.trim()).filter(Boolean))];
  const locationIds = [...new Set((raw.locationIds || []).map(String).map((value) => value.trim()).filter(Boolean))];
  if (!employeeUids.length || employeeUids.length > MAX_BULK_EMPLOYEES || !locationIds.length || locationIds.length > 20) {
    throw assignmentError('اختر من 1 إلى 100 موظف ومن 1 إلى 20 موقعاً.');
  }
  const effectiveFrom = asDate(raw.effectiveFrom) || new Date();
  const effectiveTo = asDate(raw.effectiveTo);
  if (effectiveTo && effectiveTo < effectiveFrom) throw assignmentError('تاريخ نهاية الإسناد يسبق تاريخ بدايته.');
  const defaultLocationId = raw.defaultLocationId ? String(raw.defaultLocationId) : null;
  const mode = raw.mode === 'remove' ? 'remove' : 'assign';
  if (employeeUids.length * locationIds.length > 400) {
    throw assignmentError('العملية أكبر من الحد الآمن. قلّل عدد الموظفين أو المواقع ثم أعد المعاينة.', 'capacity_reached', 409);
  }
  if (defaultLocationId && !locationIds.includes(defaultLocationId)) throw assignmentError('الموقع الافتراضي يجب أن يكون ضمن المواقع المختارة.');
  return { employeeUids, locationIds, effectiveFrom, effectiveTo, defaultLocationId, mode };
}

function previewToken(input) {
  const stable = JSON.stringify({
    employeeUids: [...input.employeeUids].sort(),
    locationIds: [...input.locationIds].sort(),
    effectiveFrom: input.effectiveFrom.toISOString(),
    effectiveTo: input.effectiveTo?.toISOString() || null,
    defaultLocationId: input.defaultLocationId,
    mode: input.mode,
  });
  return crypto.createHash('sha256').update(stable).digest('hex');
}

async function previewAssignments({ admin, actor, raw }) {
  requireManager(actor);
  const input = normalizePreviewInput(raw);
  const db = admin.firestore();
  const reads = [
    ...input.employeeUids.map((id) => db.collection('users').doc(id).get()),
    ...input.locationIds.map((id) => db.collection('locations').doc(id).get()),
  ];
  const snapshots = await Promise.all(reads);
  if (snapshots.some((snapshot) => !snapshot.exists)) throw assignmentError('تعذر العثور على أحد الموظفين أو المواقع.', 'not_found', 404);
  return {
    status: 'previewed',
    previewToken: previewToken(input),
    employeeCount: input.employeeUids.length,
    locationCount: input.locationIds.length,
    assignmentCount: input.employeeUids.length * input.locationIds.length,
    mode: input.mode,
    input: {
      ...input,
      effectiveFrom: input.effectiveFrom.toISOString(),
      effectiveTo: input.effectiveTo?.toISOString() || null,
    },
  };
}

async function applyAssignments({ admin, actor, raw }) {
  requireManager(actor);
  const operationId = String(raw?.operationId || '').trim();
  if (!operationId || operationId.length > 160) throw assignmentError('معرّف العملية مطلوب.');
  const preview = await previewAssignments({ admin, actor, raw });
  if (raw.previewToken !== preview.previewToken) throw assignmentError('انتهت صلاحية المعاينة. أعد المعاينة قبل الحفظ.', 'preview_changed', 409);
  const db = admin.firestore();
  const operationRef = db.collection('attendanceLocationOperations').doc(operationId);
  const existing = await operationRef.get();
  if (existing.exists) return existing.data();
  const input = normalizePreviewInput(raw);
  const locationSnaps = await Promise.all(input.locationIds.map((id) => db.collection('locations').doc(id).get()));
  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  for (const employeeUid of input.employeeUids) {
    for (let index = 0; index < input.locationIds.length; index += 1) {
      const locationId = input.locationIds[index];
      const location = locationSnaps[index].data() || {};
      const ref = db.collection('attendanceLocationAssignments').doc(assignmentId(employeeUid, locationId));
      if (input.mode === 'remove') {
        batch.set(ref, {
          status: 'inactive',
          isActive: false,
          effectiveTo: input.effectiveTo || input.effectiveFrom,
          updatedBy: actor.uid,
          updatedAt: now,
        }, { merge: true });
        continue;
      }
      batch.set(ref, {
        employeeUid, locationId, locationName: String(location.name || ''), status: 'active',
        effectiveFrom: admin.firestore.Timestamp.fromDate(input.effectiveFrom),
        effectiveTo: input.effectiveTo ? admin.firestore.Timestamp.fromDate(input.effectiveTo) : null,
        priority: index, isDefault: input.defaultLocationId === locationId,
        version: admin.firestore.FieldValue.increment(1), updatedAt: now,
        updatedBy: actor.uid, createdAt: now, createdBy: actor.uid,
      }, { merge: true });
    }
    if (input.defaultLocationId) {
      const defaultIndex = input.locationIds.indexOf(input.defaultLocationId);
      const defaultLocation = locationSnaps[defaultIndex].data() || {};
      batch.set(db.collection('users').doc(employeeUid), {
        locationId: input.defaultLocationId,
        locationName: String(defaultLocation.name || ''),
        updatedAt: now,
      }, { merge: true });
    }
  }
  const receipt = {
    operationId, status: 'applied', actorUid: actor.uid,
    mode: input.mode,
    employeeCount: input.employeeUids.length,
    assignmentCount: preview.assignmentCount,
    previewToken: preview.previewToken,
    createdAt: now,
  };
  batch.set(operationRef, receipt);
  batch.set(db.collection('auditLogs').doc(`attendance_location_${operationId}`), {
    ...receipt,
    action: input.mode === 'remove'
      ? 'attendance_location_assignments_removed'
      : 'attendance_location_assignments_applied',
    targetCollection: 'attendanceLocationAssignments',
  });
  await batch.commit();
  return receipt;
}

function serializeTimestamp(value) {
  const date = asDate(value);
  return date ? date.toISOString() : null;
}

async function listAssignments({ admin, actor, employeeUid, limit = 20 }) {
  const targetUid = String(employeeUid || actor?.uid || '').trim();
  if (!targetUid) throw assignmentError('حساب الموظف غير محدد.');
  if (targetUid !== actor?.uid) requireManager(actor);
  const safeLimit = Math.max(1, Math.min(Number(limit) || 20, 100));
  const db = admin.firestore();
  const snapshot = await db.collection('attendanceLocationAssignments')
    .where('employeeUid', '==', targetUid)
    .limit(safeLimit)
    .get();
  const assignments = snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
  const locationIds = [...new Set(assignments.map((item) => String(item.locationId || '')).filter(Boolean))];
  const locationSnaps = await Promise.all(locationIds.map((id) => db.collection('locations').doc(id).get()));
  const locations = new Map(locationSnaps.map((snap, index) => [locationIds[index], snap.exists ? (snap.data() || {}) : null]));
  return assignments.map((item) => {
    const location = locations.get(String(item.locationId));
    const coordinates = location
      ? locationCoordinates(location)
      : { latitude: 0, longitude: 0, radius: 0 };
    return {
      id: item.id,
      employeeUid: targetUid,
      locationId: String(item.locationId),
    locationName: String(location?.name || item.locationName || ''),
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      radiusMeters: coordinates.radius,
      status: String(item.status || (item.isActive === true ? 'active' : 'inactive')),
      isActive: item.status === 'active' || item.isActive === true,
      locationIsActive: Boolean(location) && location.isActive !== false,
      version: Number(item.version || 1),
      priority: Number(item.priority || 0),
      isDefault: item.isDefault === true,
      effectiveFrom: serializeTimestamp(item.effectiveFrom),
      effectiveTo: serializeTimestamp(item.effectiveTo),
    };
  }).sort((a, b) => a.priority - b.priority || a.locationId.localeCompare(b.locationId));
}

async function getAssignmentOperation({ admin, actor, operationId }) {
  requireManager(actor);
  const id = String(operationId || '').trim();
  if (!/^[A-Za-z0-9_.:-]{1,160}$/.test(id)) throw assignmentError('معرّف العملية غير صالح.');
  const snap = await admin.firestore().collection('attendanceLocationOperations').doc(id).get();
  if (!snap.exists) throw assignmentError('العملية غير موجودة.', 'not_found', 404);
  return snap.data() || {};
}

module.exports = {
  MAX_BULK_EMPLOYEES,
  assignmentError,
  assignmentId,
  haversineMeters,
  loadMultiLocationFlag,
  validateAssignedLocation,
  canManageAttendanceLocations,
  previewAssignments,
  applyAssignments,
  listAssignments,
  getAssignmentOperation,
};
