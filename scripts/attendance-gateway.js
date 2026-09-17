// Secure attendance write gateway.  Firebase Admin performs the final write,
// so employees never receive a Firestore-rule or quota error while checking
// in/out.  The caller is still authenticated with a Firebase ID token by the
// HTTP host before this module is reached.

const { checkoutDisabledResult, loadCheckoutPolicy } = require('./checkout-policy');
const { assertWebAttendanceAccess } = require('./web-attendance-access');
const {
  loadMultiLocationFlag,
  validateAssignedLocation,
} = require('./attendance-location-assignments');
const { isAttendanceFlagEnabled } = require('./feature-flags');
const {
  validateEarlyLeaveForCheckout,
  buildCheckoutEvidence,
  consequenceFrom,
  notifyHrReviewers,
} = require('./early-leave-reconciliation');

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

function canResetAttendanceDevice(actor) {
  if (['super_admin', 'hr_admin', 'hr_manager'].includes(actor?.role)) return true;
  if (actor?.role !== 'manager') return false;
  const unit = `${actor.department || ''} ${actor.position || ''}`.toLowerCase();
  return unit.includes('information technology') ||
    /(^|[^a-z])it([^a-z]|$)/.test(unit) ||
    unit.includes('تكنولوجيا المعلومات') || unit.includes('تقنية المعلومات');
}

function parseAction(raw, actor) {
  if (!raw || typeof raw !== 'object') throw gatewayError('Attendance action is required.');
  const type = raw.type === 'checkOut' ? 'checkOut' : raw.type === 'checkIn' ? 'checkIn' : '';
  if (!type) throw gatewayError('Attendance action type is invalid.');
  const date = asString(raw.date);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw gatewayError('Attendance date is invalid.');
  const now = new Date();
  const clientEventTime = new Date(Number(raw.eventTime));
  if (Number.isNaN(clientEventTime.getTime()) || Math.abs(now.getTime() - clientEventTime.getTime()) > 24 * 60 * 60 * 1000) {
    throw gatewayError('Attendance time is outside the allowed window.', 'stale_event');
  }
  const clockSkewMs = clientEventTime.getTime() - now.getTime();
  if (clockSkewMs > 15 * 60 * 1000) {
    throw gatewayError('وقت تسجيل الحضور يتجاوز وقت الخادم.', 'stale_event');
  }
  // Mobile clocks can drift even when the device has connectivity. For a
  // bounded future skew, use the server receipt time as business evidence and
  // retain the submitted time for audit instead of blocking the employee.
  const eventTimeNormalized = clockSkewMs > 60 * 1000;
  const eventTime = eventTimeNormalized ? now : clientEventTime;
  const latitude = asNumber(raw.latitude, NaN);
  const longitude = asNumber(raw.longitude, NaN);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    throw gatewayError('Attendance location is invalid.');
  }
  const deviceId = asString(raw.deviceId);
  if (!deviceId || deviceId.length > 256) throw gatewayError('Attendance device is invalid.');
  return {
    type, date, eventTime, clientEventTime, eventTimeNormalized,
    clientClockSkewSeconds: Math.round(clockSkewMs / 1000),
    latitude, longitude, deviceId, raw, actor,
  };
}

async function bindTrustedDevice({ db, admin, actor, action, userRef, user, developerDeviceOverride = false }) {
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
      // binding remains protected and requires HR to reset it explicitly,
      // except for executive accounts which may switch between authorized devices.
      const empCode = String(user.employeeId || user.employeeCode || '').trim().toUpperCase();
      const isExecutive = empCode === 'CEO-100' || empCode === 'COO-1300' || user.role === 'super_admin';
      if (registeredSnap.exists && registeredSnap.data()?.userId === actor.uid && !isExecutive && !developerDeviceOverride) {
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

async function hasDeveloperDeviceOverride(db, userId) {
  const entitlement = await db.collection('developerToolEntitlements').doc(userId).get();
  if (!entitlement.exists) return false;
  const data = entitlement.data() || {};
  if (data.revokedAt != null || !Array.isArray(data.scopes) || !data.scopes.includes('attendance_device_override')) return false;
  if (data.permanent === true) return true;
  const expiresAt = data.expiresAt?.toDate?.() || data.expiresAt;
  return expiresAt instanceof Date && expiresAt.getTime() > Date.now();
}

function actionData({ admin, action, user, receivedAt, locationEvidence = null, webLocationExempt = false, webGrantRevision = null }) {
  const raw = action.raw;
  const delayed = receivedAt.getTime() - action.eventTime.getTime() > 2 * 60 * 1000;
  const review = delayed || action.eventTimeNormalized || raw.securityReviewStatus === 'pending_hr';
  const base = {
    userId: action.actor.uid,
    employeeId: asString(user.employeeId),
    employeeName: asString(user.displayName),
    locationId: webLocationExempt ? '' : locationEvidence?.locationId || asString(user.locationId),
    locationName: webLocationExempt ? 'حضور ويب دون موقع' : locationEvidence?.locationName || asString(user.locationName),
    ...(webLocationExempt ? { webLocationExempt: true, webAttendanceGrantRevision: webGrantRevision } : {}),
    managerId: asString(user.managerId),
    date: action.date,
    securityProtocolVersion: 2,
    ...(action.eventTimeNormalized ? {
      clientSubmittedEventTime: admin.firestore.Timestamp.fromDate(action.clientEventTime),
      clientClockSkewSeconds: action.clientClockSkewSeconds,
      eventTimeNormalizedToServer: true,
    } : {}),
  };
  if (action.type === 'checkIn') {
    return {
      ...base,
      checkInTime: admin.firestore.Timestamp.fromDate(action.eventTime),
      ...(webLocationExempt ? {} : { checkInLocation: new admin.firestore.GeoPoint(action.latitude, action.longitude) }),
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
      locationRiskReasons: [
        ...(webLocationExempt ? ['web_location_exempt'] : Array.isArray(raw.locationRiskReasons) ? raw.locationRiskReasons.slice(0, 10) : []),
        ...(action.eventTimeNormalized ? ['client_clock_ahead'] : []),
      ],
      locationRiskMessage: action.eventTimeNormalized
        ? 'تم ضبط وقت الحضور حسب وقت الخادم بسبب اختلاف ساعة الجهاز، وسيتم مراجعته.'
        : delayed ? 'تمت مزامنة الحضور بعد انقطاع مؤقت وسيتم مراجعته.' : asString(raw.locationRiskMessage),
      locationAccuracyMeters: locationEvidence?.accuracyMeters ?? Math.max(0, asNumber(raw.accuracyMeters)),
      locationDistanceMeters: locationEvidence?.distanceMeters ?? Math.max(0, asNumber(raw.distanceMeters)),
      locationConfiguredRadiusMeters: locationEvidence?.configuredRadiusMeters ?? Math.max(0, asNumber(raw.allowedRadius)),
      locationAllowedRadiusMeters: locationEvidence?.allowedRadiusMeters ?? Math.max(0, asNumber(raw.allowedRadius)),
      ...(locationEvidence ? {
        attendanceLocationAssignmentId: locationEvidence.assignmentId,
        attendanceLocationAssignmentVersion: locationEvidence.assignmentVersion,
        attendanceLocationValidatedAt: admin.firestore.Timestamp.fromDate(locationEvidence.validatedAt),
      } : {}),
      locationMocked: false,
      locationCapturedOffline: delayed,
      status: ['present', 'late', 'late_quarter_day', 'late_half_day', 'late_full_day'].includes(raw.status) ? raw.status : 'present',
    };
  }
  return {
    checkOutTime: admin.firestore.Timestamp.fromDate(action.eventTime),
    ...(webLocationExempt ? {} : { checkOutLocation: new admin.firestore.GeoPoint(action.latitude, action.longitude) }),
    ...(webLocationExempt ? { webCheckoutLocationExempt: true, webAttendanceGrantRevision: webGrantRevision } : {}),
    localCheckOutTime: admin.firestore.Timestamp.fromDate(action.eventTime),
    totalWorkHours: Math.max(0, asNumber(raw.totalWorkHours)),
    checkOutDeviceId: action.deviceId,
    checkOutDeviceLabel: asString(raw.deviceLabel, 'Unknown device'),
    checkOutBiometricVerified: raw.biometricVerified === true,
    checkoutSecurityReviewStatus: review ? 'pending_hr' : 'none',
    checkoutLocationRiskLevel: review ? 'high' : asString(raw.locationRiskLevel, 'low'),
    checkoutLocationRiskReasons: [
      ...(Array.isArray(raw.locationRiskReasons) ? raw.locationRiskReasons.slice(0, 10) : []),
      ...(action.eventTimeNormalized ? ['client_clock_ahead'] : []),
    ],
    checkoutLocationRiskMessage: action.eventTimeNormalized
      ? 'تم ضبط وقت الانصراف حسب وقت الخادم بسبب اختلاف ساعة الجهاز، وسيتم مراجعته.'
      : delayed ? 'تمت مزامنة الانصراف بعد انقطاع مؤقت وسيتم مراجعته.' : asString(raw.locationRiskMessage),
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
  let action;
  try {
    action = parseAction(rawAction, actor);
  } catch (error) {
    // A delayed queue can replay after its original check-in already succeeded.
    // Return the deterministic receipt instead of turning a successful action
    // into a stale-event error. This path is actor-owned and performs no write.
    const rawDate = asString(rawAction?.date);
    const expectedId = `${actor.uid}_${rawDate}`;
    if (error?.code === 'stale_event' && rawAction?.type === 'checkIn' &&
        /^\d{4}-\d{2}-\d{2}$/.test(rawDate) && asString(rawAction?.attendanceId) === expectedId) {
      const [userSnap, attendanceSnap] = await Promise.all([
        db.collection('users').doc(actor.uid).get(),
        db.collection('attendance').doc(expectedId).get(),
      ]);
      if (userSnap.exists && userSnap.data()?.isActive !== false &&
          attendanceSnap.exists && attendanceSnap.data()?.checkInTime) {
        return { action: 'check_in', status: 'already_recorded', attendanceId: expectedId };
      }
    }
    throw error;
  }
  // Web attendance is an explicit, employee-specific exception. This lookup is
  // intentionally in the write gateway so a stale or altered browser cannot
  // authorize an action after a grant expires or is revoked.
  const webGrant = action.raw.clientPlatform === 'web'
    ? await assertWebAttendanceAccess({ admin, actor })
    : null;
  const webLocationExempt = webGrant?.allowAnyLocation === true;
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
  const ref = db.collection('attendance').doc(expectedId);
  const developerDeviceOverride = await hasDeveloperDeviceOverride(db, actor.uid);
  const receivedAt = new Date();
  if (action.type === 'checkIn') {
    // A retry must converge even when the employee's assignments changed after
    // the original successful event. Location is evidence, not record identity.
    const duplicate = await ref.get();
    if (duplicate.exists && duplicate.data()?.checkInTime) {
      return { action: 'check_in', status: 'already_recorded', attendanceId: expectedId };
    }
    const multiLocationEnabled = await loadMultiLocationFlag(db, actor.uid);
    const locationEvidence = multiLocationEnabled && !webLocationExempt
      ? await validateAssignedLocation({
        db, actorUid: actor.uid, rawAction, eventTime: action.eventTime,
      })
      : null;
    await bindTrustedDevice({ db, admin, actor, action, userRef, user, developerDeviceOverride });
    // Use a transaction for the canonical Cairo-day identity. Two retries (or
    // an automatic/manual race) therefore converge to one record and a
    // semantic receipt instead of leaking an "already exists" error.
    const status = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists && existing.data()?.checkInTime) {
        return 'already_recorded';
      }
      transaction.set(ref, actionData({
        admin, action, user, receivedAt, locationEvidence,
        webLocationExempt, webGrantRevision: webGrant?.revision ?? null,
      }), {
        merge: false,
      });
      return 'recorded';
    });
    return { action: 'check_in', status, attendanceId: expectedId };
  }
  await bindTrustedDevice({ db, admin, actor, action, userRef, user, developerDeviceOverride });

  let earlyLeave = null;
  let permissionRef = null;
  let permission = null;
  const permissionId = asString(rawAction.earlyLeavePermissionId);
  if (permissionId) {
    const securitySnap = await db.collection('publicConfig').doc('appSecurity').get();
    const enabled = isAttendanceFlagEnabled(
      'pending_early_leave_checkout_v1', securitySnap.data() || {}, actor.uid,
    );
    if (!enabled) {
      throw gatewayError('Early-leave checkout is not enabled.', 'invalid_early_leave_request');
    }
    permissionRef = db.collection('permissions').doc(permissionId);
    const permissionSnap = await permissionRef.get();
    permission = permissionSnap.exists ? permissionSnap.data() : null;
    earlyLeave = validateEarlyLeaveForCheckout({
      permissionId,
      permission,
      actorUid: actor.uid,
      dateKey: action.date,
      eventTime: action.eventTime,
      normalEndTime: user.workSchedule?.endTime || '17:00',
    });
  }

  const result = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (!existing.exists || !existing.data()?.checkInTime) {
      throw gatewayError('سجل الحضور غير موجود بعد.', 'checkin_missing');
    }
    if (existing.data()?.checkOutTime) {
      const boundPermission = existing.data()?.earlyLeaveCheckoutEvidence?.permissionId;
      if (permissionId && boundPermission && boundPermission !== permissionId) {
        throw gatewayError('Checkout is already bound to another request.', 'checkout_already_bound');
      }
      return { status: 'already_recorded', evidence: existing.data()?.earlyLeaveCheckoutEvidence };
    }
    const patch = actionData({ admin, action, user, receivedAt,
      webLocationExempt, webGrantRevision: webGrant?.revision ?? null });
    let evidence = null;
    if (earlyLeave?.isEarly) {
      evidence = buildCheckoutEvidence({
        validation: earlyLeave,
        eventTime: action.eventTime,
        eventId: rawAction.id,
        admin,
      });
      patch.earlyLeaveCheckoutEvidence = evidence;
    }
    transaction.set(ref, patch, { merge: true });
    if (evidence && permission?.status === 'rejected') {
      const consequence = consequenceFrom({
        permissionId,
        permission,
        attendanceId: expectedId,
        evidence,
        user,
        admin,
      });
      transaction.set(permissionRef, { rejectionConsequence: consequence }, { merge: true });
    } else if (evidence && permissionRef) {
      transaction.set(permissionRef, {
        rejectionConsequence: {
          reconciliationState: 'pending',
          attendanceId: expectedId,
          consequenceId: `early_leave_rejection:${permissionId}`,
        },
      }, { merge: true });
    }
    return { status: 'recorded', evidence };
  });
  if (result.evidence && permission?.status === 'rejected') {
    await notifyHrReviewers({
      admin,
      permissionId,
      result: {
        status: 'consequence_pending_hr',
        dayFraction: result.evidence.potentialDayFraction,
      },
    });
  }
  return {
    action: 'check_out',
    status: result.status,
    attendanceId: expectedId,
    ...(result.evidence ? {
      earlyLeave: {
        permissionId,
        requestStatus: earlyLeave?.requestStatus || result.evidence.permissionStatusAtCheckout,
        potentialDayFraction: earlyLeave?.potentialDayFraction || result.evidence.potentialDayFraction,
        consequenceStatus: permission?.status === 'rejected' ? 'pending_hr' : 'pending_decision',
      },
    } : {}),
  };
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
  const developerDeviceOverride = await hasDeveloperDeviceOverride(db, actor.uid);
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
    developerDeviceOverride,
  });
  return { action: 'device_bound', status: 'recorded' };
}

/// HR/IT-only device reset. The employee never receives direct Firestore
/// permission to remove a device binding, and every reset leaves an audit log.
async function resetAttendanceDevice({ admin, actor, employeeId, reason }) {
  if (!canResetAttendanceDevice(actor)) {
    throw gatewayError('لا تملك صلاحية إعادة ضبط جهاز الحضور.', 'not_authorized');
  }
  const targetId = asString(employeeId);
  const auditReason = asString(reason);
  if (!targetId || !auditReason || auditReason.length > 500) {
    throw gatewayError('سبب إعادة الضبط مطلوب ويجب أن يكون مختصراً.');
  }
  const db = admin.firestore();
  const userRef = db.collection('users').doc(targetId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw gatewayError('حساب الموظف غير موجود.', 'not_found');
  const user = userSnap.data() || {};
  const deviceId = asString(user.registeredAttendanceDeviceId);
  const deviceRef = deviceId
    ? db.collection('attendanceDevices').doc(deviceId.replaceAll('/', '_'))
    : null;
  const auditRef = db.collection('auditLogs').doc(`attendance_device_reset_${targetId}_${Date.now()}`);
  await db.runTransaction(async (transaction) => {
    transaction.set(userRef, {
      registeredAttendanceDeviceId: admin.firestore.FieldValue.delete(),
      registeredAttendanceDeviceLabel: admin.firestore.FieldValue.delete(),
      registeredAttendanceDeviceAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    if (deviceRef) transaction.delete(deviceRef);
    transaction.set(auditRef, {
      actorId: actor.uid,
      action: 'attendance_device_reset',
      targetCollection: 'users',
      targetId,
      reason: auditReason,
      previousDeviceId: deviceId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return { action: 'device_reset', status: 'recorded', employeeId: targetId };
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
  resetAttendanceDevice,
  canResetAttendanceDevice,
  resolveCheckInStatus,
};
