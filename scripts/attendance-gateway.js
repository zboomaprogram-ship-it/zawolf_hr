// Secure attendance write gateway.  Firebase Admin performs the final write,
// so employees never receive a Firestore-rule or quota error while checking
// in/out.  The caller is still authenticated with a Firebase ID token by the
// HTTP host before this module is reached.

const { checkoutDisabledResult, loadCheckoutPolicy } = require('./checkout-policy');

const CAIRO_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
});

function cairoDateKey(date = new Date()) {
  return CAIRO_FORMATTER.format(date);
}

function asNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function asString(value, fallback = '') {
  return typeof value === 'string' ? value.trim() : fallback;
}

function gatewayError(message, code = 'invalid_request') {
  const error = new Error(message);
  error.code = code;
  return error;
}

function parseAction(raw, actor) {
  if (!raw || typeof raw !== 'object') throw gatewayError('Attendance action is required.');
  const type = raw.type === 'checkOut' ? 'checkOut' : raw.type === 'checkIn' ? 'checkIn' : '';
  if (!type) throw gatewayError('Attendance action type is invalid.');
  const date = asString(raw.date);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw gatewayError('Attendance date is invalid.');
  const now = new Date();
  const eventTime = new Date(Number(raw.eventTime));
  if (Number.isNaN(eventTime.getTime()) || Math.abs(now.getTime() - eventTime.getTime()) > 24 * 60 * 60 * 1000) {
    throw gatewayError('Attendance time is outside the allowed window.', 'stale_event');
  }
  const latitude = asNumber(raw.latitude, NaN);
  const longitude = asNumber(raw.longitude, NaN);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    throw gatewayError('Attendance location is invalid.');
  }
  const deviceId = asString(raw.deviceId);
  if (!deviceId || deviceId.length > 256) throw gatewayError('Attendance device is invalid.');
  return { type, date, eventTime, latitude, longitude, deviceId, raw, actor };
}

async function bindTrustedDevice({ db, admin, actor, action, userRef, user }) {
  const deviceRef = db.collection('attendanceDevices').doc(action.deviceId.replaceAll('/', '_'));
  await db.runTransaction(async (transaction) => {
    const deviceSnap = await transaction.get(deviceRef);
    const registered = asString(user.registeredAttendanceDeviceId);
    if (deviceSnap.exists && deviceSnap.data()?.userId !== actor.uid) {
      throw gatewayError('هذا الجهاز مربوط بحساب موظف آخر.', 'device_conflict');
    }
    if (registered && registered !== action.deviceId) {
      const registeredRef = db.collection('attendanceDevices').doc(registered.replaceAll('/', '_'));
      const registeredSnap = await transaction.get(registeredRef);
      // A missing/wrong legacy binding is self-healed. A verified current
      // binding remains protected and requires HR to reset it explicitly.
      if (registeredSnap.exists && registeredSnap.data()?.userId === actor.uid) {
        throw gatewayError('هذا الحساب مربوط بجهاز حضور آخر. اطلب من HR إعادة ضبط الجهاز.', 'device_mismatch');
      }
    }
    transaction.set(deviceRef, {
      deviceId: action.deviceId,
      userId: actor.uid,
      employeeId: asString(user.employeeId),
      employeeName: asString(user.displayName),
      deviceLabel: asString(action.raw.deviceLabel, 'Unknown device'),
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    transaction.set(userRef, {
      registeredAttendanceDeviceId: action.deviceId,
      registeredAttendanceDeviceLabel: asString(action.raw.deviceLabel, 'Unknown device'),
      registeredAttendanceDeviceAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

function actionData({ admin, action, user, receivedAt }) {
  const raw = action.raw;
  const delayed = receivedAt.getTime() - action.eventTime.getTime() > 2 * 60 * 1000;
  const review = delayed || raw.securityReviewStatus === 'pending_hr';
  const base = {
    userId: action.actor.uid,
    employeeId: asString(user.employeeId),
    employeeName: asString(user.displayName),
    locationId: asString(user.locationId),
    locationName: asString(user.locationName),
    managerId: asString(user.managerId),
    date: action.date,
    securityProtocolVersion: 2,
  };
  if (action.type === 'checkIn') {
    return {
      ...base,
      checkInTime: admin.firestore.Timestamp.fromDate(action.eventTime),
      checkInLocation: new admin.firestore.GeoPoint(action.latitude, action.longitude),
      localCheckInTime: admin.firestore.Timestamp.fromDate(action.eventTime),
      isWithinGeofence: true,
      isLate: raw.isLate === true,
      lateMinutes: Math.max(0, Math.round(asNumber(raw.lateMinutes))),
      salaryDeductionFraction: Math.max(0, Math.min(1, asNumber(raw.salaryDeductionFraction))),
      salaryDeductionAmount: Math.max(0, asNumber(raw.salaryDeductionAmount)),
      salaryCurrency: asString(raw.salaryCurrency, 'EGP'),
      salaryDeductionCode: asString(raw.salaryDeductionCode, 'none'),
      salaryDeductionLabel: asString(raw.salaryDeductionLabel, 'لا يوجد خصم'),
      salaryDeductionApprovalStatus: asString(raw.salaryDeductionApprovalStatus, 'none'),
      deviceId: action.deviceId,
      deviceLabel: asString(raw.deviceLabel, 'Unknown device'),
      biometricVerified: raw.biometricVerified === true,
      securityReviewStatus: review ? 'pending_hr' : 'none',
      locationRiskLevel: review ? 'high' : asString(raw.locationRiskLevel, 'low'),
      locationRiskReasons: Array.isArray(raw.locationRiskReasons) ? raw.locationRiskReasons.slice(0, 10) : [],
      locationRiskMessage: delayed ? 'تمت مزامنة الحضور بعد انقطاع مؤقت وسيتم مراجعته.' : asString(raw.locationRiskMessage),
      locationAccuracyMeters: Math.max(0, asNumber(raw.accuracyMeters)),
      locationDistanceMeters: Math.max(0, asNumber(raw.distanceMeters)),
      locationAllowedRadiusMeters: Math.max(0, asNumber(raw.allowedRadius)),
      locationMocked: false,
      locationCapturedOffline: delayed,
      status: ['present', 'late', 'late_quarter_day', 'late_half_day', 'late_full_day'].includes(raw.status) ? raw.status : 'present',
    };
  }
  return {
    checkOutTime: admin.firestore.Timestamp.fromDate(action.eventTime),
    checkOutLocation: new admin.firestore.GeoPoint(action.latitude, action.longitude),
    localCheckOutTime: admin.firestore.Timestamp.fromDate(action.eventTime),
    totalWorkHours: Math.max(0, asNumber(raw.totalWorkHours)),
    checkOutDeviceId: action.deviceId,
    checkOutDeviceLabel: asString(raw.deviceLabel, 'Unknown device'),
    checkOutBiometricVerified: raw.biometricVerified === true,
    checkoutSecurityReviewStatus: review ? 'pending_hr' : 'none',
    checkoutLocationRiskLevel: review ? 'high' : asString(raw.locationRiskLevel, 'low'),
    checkoutLocationRiskReasons: Array.isArray(raw.locationRiskReasons) ? raw.locationRiskReasons.slice(0, 10) : [],
    checkoutLocationRiskMessage: delayed ? 'تمت مزامنة الانصراف بعد انقطاع مؤقت وسيتم مراجعته.' : asString(raw.locationRiskMessage),
    checkoutLocationAccuracyMeters: Math.max(0, asNumber(raw.accuracyMeters)),
    checkoutLocationDistanceMeters: Math.max(0, asNumber(raw.distanceMeters)),
    checkoutLocationAllowedRadiusMeters: Math.max(0, asNumber(raw.allowedRadius)),
    checkoutLocationMocked: false,
    checkoutLocationCapturedOffline: delayed,
    securityProtocolVersion: 2,
  };
}

async function submitAttendanceAction({ admin, actor, rawAction }) {
  const db = admin.firestore();
  const action = parseAction(rawAction, actor);
  // Keep this guard in the write gateway itself.  HTTP handlers, workers, or
  // future API routes must not be able to bypass the company check-out policy.
  // This happens before device binding or attendance mutation.
  if (action.type === 'checkOut') {
    const checkoutPolicy = await loadCheckoutPolicy(db);
    if (!checkoutPolicy.enabled) {
      return checkoutDisabledResult({
        attendanceId: `${actor.uid}_${action.date}`,
        policy: checkoutPolicy,
      });
    }
  }
  const userRef = db.collection('users').doc(actor.uid);
  const userSnap = await userRef.get();
  const user = userSnap.data() || {};
  if (!userSnap.exists || user.isActive === false) throw gatewayError('حساب الموظف غير نشط.', 'account_inactive');
  const expectedId = `${actor.uid}_${action.date}`;
  if (asString(rawAction.attendanceId) !== expectedId) throw gatewayError('Attendance identity is invalid.');
  await bindTrustedDevice({ db, admin, actor, action, userRef, user });
  const ref = db.collection('attendance').doc(expectedId);
  const receivedAt = new Date();
  if (action.type === 'checkIn') {
    const existing = await ref.get();
    if (!existing.exists) await ref.create(actionData({ admin, action, user, receivedAt }));
    return { action: 'check_in', status: existing.exists ? 'already_recorded' : 'recorded', attendanceId: expectedId };
  }
  const existing = await ref.get();
  if (!existing.exists || !existing.data()?.checkInTime) throw gatewayError('سجل الحضور غير موجود بعد.', 'checkin_missing');
  if (existing.data()?.checkOutTime) return { action: 'check_out', status: 'already_recorded', attendanceId: expectedId };
  await ref.update(actionData({ admin, action, user, receivedAt }));
  return { action: 'check_out', status: 'recorded', attendanceId: expectedId };
}

async function bindAttendanceDevice({ admin, actor, rawAction }) {
  const deviceId = asString(rawAction?.deviceId);
  if (!deviceId || deviceId.length > 256) {
    throw gatewayError('Attendance device is invalid.');
  }
  const db = admin.firestore();
  const userRef = db.collection('users').doc(actor.uid);
  const userSnap = await userRef.get();
  const user = userSnap.data() || {};
  if (!userSnap.exists || user.isActive === false) {
    throw gatewayError('حساب الموظف غير نشط.', 'account_inactive');
  }
  await bindTrustedDevice({
    db,
    admin,
    actor,
    action: {
      deviceId,
      raw: { deviceLabel: asString(rawAction?.deviceLabel, 'Unknown device') },
    },
    userRef,
    user,
  });
  return { action: 'device_bound', status: 'recorded' };
}

/// Returns only the caller's check-in state for a deterministic attendance ID.
/// It deliberately does not leak another employee's attendance existence.
async function resolveCheckInStatus({ admin, actor, attendanceId }) {
  const expectedPrefix = `${actor.uid}_`;
  if (typeof attendanceId !== 'string' ||
      !attendanceId.startsWith(expectedPrefix) ||
      !/^.+_\d{4}-\d{2}-\d{2}$/.test(attendanceId)) {
    throw gatewayError('Attendance identity is invalid.');
  }
  const snap = await admin.firestore().collection('attendance').doc(attendanceId).get();
  return {
    action: 'check_in',
    attendanceId,
    status: snap.exists && snap.data()?.checkInTime ? 'already_recorded' : 'not_recorded',
  };
}

module.exports = {
  submitAttendanceAction,
  bindAttendanceDevice,
  resolveCheckInStatus,
};
