const admin = require('firebase-admin');
const {
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');
const { loadCheckoutPolicy } = require('./checkout-policy');
const { validateAssignedLocation } = require('./attendance-location-assignments');

installFirestoreCompatibility(admin);

const CAIRO_TIME_ZONE = 'Africa/Cairo';
const MAX_SIGNAL_AGE_MS = 15 * 60 * 1000;
const MAX_LOCATION_ACCURACY_METERS = 25;
const DEFAULT_RETURN_GRACE_MINUTES = 15;
const DEFAULT_COMPANY_BREAK_START = 13 * 60;
const DEFAULT_COMPANY_BREAK_END = 14 * 60;

function initializeFirebase() {
  const existingApp = getExistingFirebaseApp(admin);
  if (existingApp) return existingApp;
  return admin.initializeApp({
    credential: admin.cert(parseFirebaseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT)),
  });
}

function cairoParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: CAIRO_TIME_ZONE,
    year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(date);
  const get = (type) => parts.find((part) => part.type === type)?.value || '';
  return {
    dateKey: `${get('year')}-${get('month')}-${get('day')}`,
    weekday: get('weekday'),
    minutes: Number(get('hour')) * 60 + Number(get('minute')),
  };
}

function parseMinutes(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const [hour, minute] = value.split(':').map(Number);
  return Number.isInteger(hour) && Number.isInteger(minute)
    ? Math.max(0, Math.min(1439, hour * 60 + minute))
    : fallback;
}

function timestampToDateKey(value) {
  if (!value) return null;
  if (typeof value === 'string') return value.match(/^\d{4}-\d{2}-\d{2}/)?.[0] || null;
  const date = typeof value.toDate === 'function' ? value.toDate() : value;
  return date instanceof Date && !Number.isNaN(date.getTime()) ? cairoParts(date).dateKey : null;
}

function isWorkDay(user, weekday) {
  const map = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  const days = user.workSchedule?.workDays;
  return Array.isArray(days) && days.length ? days.includes(map[weekday]) : weekday !== 'Fri';
}

function withinLeave(leave, dateKey) {
  const start = timestampToDateKey(leave.startDate);
  const end = timestampToDateKey(leave.endDate);
  return Boolean(start && end && start <= dateKey && dateKey <= end);
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const rad = (value) => value * Math.PI / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2
    + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function effectiveTimes(user, policy, permissions) {
  const baseStart = parseMinutes(user.workSchedule?.startTime, parseMinutes(policy.defaultStartTime, 9 * 60));
  const baseEnd = parseMinutes(user.workSchedule?.endTime, parseMinutes(policy.defaultEndTime, 17 * 60));
  const late = permissions.find((item) => item.permissionType === 'late_arrival');
  const early = permissions.find((item) => item.permissionType === 'early_leave');
  return {
    start: baseStart + Math.max(0, Number(late?.durationMinutes || 0)),
    end: baseEnd - Math.max(0, Number(early?.durationMinutes || 0)),
  };
}

function permissionReturnWindow(permission, workTimes) {
  if (permission?.permissionType !== 'mid_shift_exit') return null;
  const start = parseMinutes(permission.expectedTime, -1);
  const duration = Math.max(0, Number(permission.durationMinutes || 0));
  if (start < 0 || duration <= 0) return null;
  const end = Math.min(workTimes.end, start + duration);
  return end > start ? { start, end, reason: 'approved_mid_shift_permission' } : null;
}

function activeReturnException({ nowMinutes, permissions, workTimes, policy }) {
  const permission = permissions
    .map((item) => permissionReturnWindow(item, workTimes))
    .find((item) => item && nowMinutes >= item.start && nowMinutes < item.end);
  if (permission) return permission;
  const breakStart = parseMinutes(policy.companyBreakStartTime, DEFAULT_COMPANY_BREAK_START);
  const breakEnd = parseMinutes(policy.companyBreakEndTime, DEFAULT_COMPANY_BREAK_END);
  if (breakEnd > breakStart && nowMinutes >= breakStart && nowMinutes < breakEnd) {
    return { start: breakStart, end: breakEnd, reason: 'company_break' };
  }
  return null;
}

function returnGraceDeadline({ now, nowMinutes, exception, policy }) {
  const returnGraceMinutes = Math.max(
    1,
    Math.min(180, Number(policy.autoCheckoutReturnGraceMinutes || DEFAULT_RETURN_GRACE_MINUTES)),
  );
  const remainingException = exception ? Math.max(0, exception.end - nowMinutes) : 0;
  return new Date(now.getTime() + (remainingException + returnGraceMinutes) * 60 * 1000);
}

function deductionFor(nowMinutes, startMinutes, policy, salary, currency) {
  const lateMinutes = Math.max(0, nowMinutes - startMinutes);
  const grace = Number(policy.graceMinutes ?? 15);
  const quarterUntil = Number(policy.quarterDayUntilMinutes ?? 30);
  const halfUntil = Number(policy.halfDayUntilMinutes ?? 60);
  let fraction = 0;
  let code = 'none';
  let label = 'لا يوجد خصم';
  let status = 'present';
  if (lateMinutes > grace && lateMinutes <= quarterUntil) {
    fraction = 0.25; code = 'quarter_day'; label = 'خصم ربع يوم'; status = 'late_quarter_day';
  } else if (lateMinutes > quarterUntil && lateMinutes <= halfUntil) {
    fraction = 0.5; code = 'half_day'; label = 'خصم نصف يوم'; status = 'late_half_day';
  } else if (lateMinutes > halfUntil) {
    fraction = 1; code = 'full_day'; label = 'خصم يوم كامل'; status = 'late_full_day';
  }
  const payrollDays = Math.max(1, Number(policy.payrollWorkDaysPerMonth ?? 26));
  return {
    fraction, code, label, status, lateMinutes,
    amount: fraction > 0 ? (Number(salary || 0) / payrollDays) * fraction : 0,
    currency: currency || 'EGP',
  };
}

async function writeHrNotification(db, title, body, data, type = 'salary_deduction_pending') {
  const hrUsers = await db.collection('users').get();
  const batch = db.batch();
  let count = 0;
  for (const userDoc of hrUsers.docs) {
    const user = userDoc.data();
    if (user?.isActive === false) continue;
    const role = user.role;
    if (role !== 'hr_admin' && role !== 'hr_manager' && role !== 'super_admin') continue;
    const notification = db.collection('notifications').doc(userDoc.id).collection('items').doc();
    batch.set(notification, {
      notificationId: notification.id,
      type, title, body, data,
      isRead: false, pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(userDoc.ref, { unreadNotifications: admin.firestore.FieldValue.increment(1) });
    count++;
  }
  if (count) await batch.commit();
}

function activeWorkingPeriod({ nowMinutes, workTimes, permissions, policy }) {
  if (nowMinutes < workTimes.start || nowMinutes >= workTimes.end) return null;
  const exception = activeReturnException({
    nowMinutes,
    permissions,
    workTimes,
    policy,
  });
  if (exception) return null;
  return {
    start: workTimes.start,
    end: workTimes.end,
    key: `${workTimes.start}-${workTimes.end}`,
  };
}

// An EXIT is an OS region-boundary event, not payroll evidence.  We record one
// reviewable alert per employee/location/working period and notify HR.  The
// document ID is the idempotency boundary when Android or iOS re-delivers an
// event, or the worker retries after a failure.
async function createLocationExitAlert({
  db, userDoc, user, signal, signalTime, capturedAt, location, period,
}) {
  const alertId = [
    signalTime.dateKey,
    userDoc.id,
    String(signal.locationId || 'assigned'),
    period.key,
  ].join('_').replace(/[^a-zA-Z0-9_-]/g, '-');
  const alertRef = db.collection('attendanceLocationExitAlerts').doc(alertId);
  const created = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(alertRef);
    if (existing.exists) return false;
    transaction.create(alertRef, {
      alertId,
      userId: userDoc.id,
      employeeId: user.employeeId || '',
      employeeName: user.displayName || user.employeeId || 'موظف',
      managerId: user.managerId || null,
      date: signalTime.dateKey,
      locationId: signal.locationId || null,
      locationName: location.name || signal.locationName || '',
      eventAt: admin.firestore.Timestamp.fromDate(capturedAt),
      workingPeriodStartMinutes: period.start,
      workingPeriodEndMinutes: period.end,
      source: signal.source,
      status: 'open',
      resolution: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!created) return { created: false, alertId };
  const employeeName = user.displayName || user.employeeId || 'موظف';
  const locationName = location.name || signal.locationName || 'موقع الحضور';
  await writeHrNotification(
    db,
    'تنبيه مغادرة موقع العمل',
    `غادر ${employeeName} نطاق ${locationName} أثناء وقت الدوام بدون إذن أو مأمورية معتمدة. يرجى المراجعة.`,
    { alertId, userId: userDoc.id, date: signalTime.dateKey, locationId: signal.locationId || null },
    'attendance_location_exit',
  );
  return { created: true, alertId };
}

async function resolveSignal(db, signalDoc, outcome, extra = {}) {
  await signalDoc.ref.update({
    status: outcome,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  });
}

async function processSignal(db, signalDoc, company, now, checkoutPolicy, multiLocationEnabled = false) {
  const signal = signalDoc.data();
  const capturedAt = signal.createdAt?.toDate?.();
  if (!(capturedAt instanceof Date) || Date.now() - capturedAt.getTime() > MAX_SIGNAL_AGE_MS || capturedAt.getTime() - Date.now() > 60 * 1000) {
    return resolveSignal(db, signalDoc, 'ignored_stale');
  }
  if (!['android_geofence', 'ios_region'].includes(signal.source)) {
    return resolveSignal(db, signalDoc, 'rejected_source');
  }
  if (!['enter', 'exit'].includes(signal.event)) {
    return resolveSignal(db, signalDoc, 'ignored_non_check_in_event');
  }
  if (signal.locationMocked === true) {
    return resolveSignal(db, signalDoc, 'rejected_mock_location');
  }
  // The server timestamp is the authoritative work time. The dispatcher may
  // run a minute later, so never calculate a shift from the worker's clock.
  const signalTime = cairoParts(capturedAt);
  const [userDoc, dayOffDoc] = await Promise.all([
    db.collection('users').doc(signal.userId).get(),
    db.collection('companyDayOffs').doc(signalTime.dateKey).get(),
  ]);
  if (!userDoc.exists) return resolveSignal(db, signalDoc, 'rejected_account_or_location');
  const user = userDoc.data();
  let location;
  let assignmentEvidence = null;
  if (multiLocationEnabled) {
    try {
      assignmentEvidence = await validateAssignedLocation({
        db,
        actorUid: signal.userId,
        rawAction: signal,
        eventTime: capturedAt,
      });
      location = {
        name: assignmentEvidence.locationName,
        latitude: assignmentEvidence.locationLatitude,
        longitude: assignmentEvidence.locationLongitude,
        geofenceRadiusMeters: assignmentEvidence.configuredRadiusMeters,
        isActive: true,
      };
    } catch (error) {
      return resolveSignal(db, signalDoc, `rejected_${String(error.code || 'assignment')}`);
    }
  } else {
    const locationDoc = await db.collection('locations').doc(signal.locationId).get();
    if (!locationDoc.exists) return resolveSignal(db, signalDoc, 'rejected_account_or_location');
    location = locationDoc.data();
  }
  if (!user.isActive || user.employeeId !== signal.employeeId ||
      (!multiLocationEnabled && user.locationId !== signal.locationId) ||
      user.registeredAttendanceDeviceId !== signal.deviceId || !location.isActive) {
    return resolveSignal(db, signalDoc, 'rejected_assignment');
  }
  if (!isWorkDay(user, signalTime.weekday)) return resolveSignal(db, signalDoc, 'ignored_non_work_day');
  if (dayOffDoc.exists && dayOffDoc.data()?.isActive === true) return resolveSignal(db, signalDoc, 'ignored_company_day_off');
  const [leaves, permissions, assignments] = await Promise.all([
    db.collection('leaves').where('userId', '==', userDoc.id).get(),
    db.collection('permissions').where('userId', '==', userDoc.id).get(),
    db.collection('fieldAssignments').where('userId', '==', userDoc.id).get(),
  ]);
  if (leaves.docs.some((doc) => doc.data().status === 'approved' && withinLeave(doc.data(), signalTime.dateKey))) return resolveSignal(db, signalDoc, 'ignored_approved_leave');
  const todaysPermissions = permissions.docs.map((doc) => doc.data()).filter((item) => item.status === 'approved' && item.requestDate === signalTime.dateKey);
  const fieldAssignment = assignments.docs.map((doc) => doc.data()).find((item) => item.status === 'active' && item.date === signalTime.dateKey);
  const accuracy = Number(signal.accuracyMeters);
  const distance = haversineMeters(Number(signal.latitude), Number(signal.longitude), Number(location.latitude), Number(location.longitude));
  const radius = Number(location.geofenceRadiusMeters || 50);
  // An Android/iOS EXIT signal is produced by the OS at the region boundary;
  // it is expected to be outside the radius.  ENTER must still prove that it
  // is inside the assigned location.
  if (!Number.isFinite(accuracy) || accuracy <= 0 || accuracy > MAX_LOCATION_ACCURACY_METERS ||
      !Number.isFinite(distance) || (signal.event === 'enter' && distance > radius)) {
    return resolveSignal(db, signalDoc, 'rejected_location', { accuracyMeters: accuracy, distanceMeters: distance, allowedRadiusMeters: radius });
  }
  const policy = company.attendancePolicy || company || {};
  const times = effectiveTimes(user, policy, todaysPermissions);
  // The dispatcher can run after midnight while processing an event captured
  // shortly before it. The attendance date must follow the validated signal.
  const attendanceRef = db.collection('attendance').doc(`${userDoc.id}_${signalTime.dateKey}`);
  const attendance = await attendanceRef.get();
  if (signal.event === 'enter') {
    const graceRef = db.collection('autoAttendanceReturnGraces').doc(`${userDoc.id}_${signalTime.dateKey}`);
    const grace = await graceRef.get();
    if (grace.exists && grace.data()?.status === 'pending') {
      await graceRef.update({
        status: 'returned',
        returnedAt: admin.firestore.Timestamp.fromDate(capturedAt),
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    const policyOpensAt = parseMinutes(policy.checkInOpenTime, 7 * 60);
    const employeeStartsAt = parseMinutes(user.workSchedule?.startTime, parseMinutes(policy.defaultStartTime, 9 * 60));
    const opensAt = Math.min(policyOpensAt, employeeStartsAt);
    if (signalTime.minutes < opensAt) return resolveSignal(db, signalDoc, 'ignored_before_check_in_open');
    if (attendance.exists && attendance.data()?.checkInTime) return resolveSignal(db, signalDoc, 'ignored_already_checked_in');
    const deduction = deductionFor(signalTime.minutes, times.start, policy, user.baseMonthlySalary, user.salaryCurrency);
    const automaticRecord = {
      userId: userDoc.id, employeeId: user.employeeId || '', employeeName: user.displayName || '',
      locationId: signal.locationId, locationName: location.name || signal.locationName || '',
      managerId: user.managerId || null, date: signalTime.dateKey,
      deviceId: signal.deviceId, deviceLabel: signal.deviceLabel || '',
      checkInTime: admin.firestore.Timestamp.fromDate(capturedAt),
      localCheckInTime: admin.firestore.Timestamp.fromDate(capturedAt),
      checkInLocation: new admin.firestore.GeoPoint(Number(signal.latitude), Number(signal.longitude)),
      isWithinGeofence: true, biometricVerified: false,
      automaticAttendance: true, attendanceSource: signal.source,
      locationAccuracyMeters: accuracy, locationDistanceMeters: distance, locationAllowedRadiusMeters: radius,
      ...(assignmentEvidence ? {
        attendanceLocationAssignmentId: assignmentEvidence.assignmentId,
        attendanceLocationAssignmentVersion: assignmentEvidence.assignmentVersion,
      } : {}),
      locationMocked: false, locationCapturedOffline: false,
      securityReviewStatus: 'none', locationRiskLevel: 'low', locationRiskReasons: [],
      isLate: deduction.fraction > 0, lateMinutes: deduction.lateMinutes,
      salaryDeductionFraction: deduction.fraction, salaryDeductionAmount: deduction.amount,
      salaryCurrency: deduction.currency, salaryDeductionCode: deduction.code,
      salaryDeductionLabel: deduction.label,
      salaryDeductionApprovalStatus: deduction.fraction > 0 ? 'pending_hr' : 'none',
      status: deduction.status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    try {
      // Never merge an automatic event into a concurrent manual record. The
      // deterministic document ID is the idempotency boundary for both.
      await attendanceRef.create(automaticRecord);
    } catch (error) {
      const duplicate = String(error?.code || '').includes('already') ||
        String(error?.message || error).toLowerCase().includes('already exists');
      if (duplicate) return resolveSignal(db, signalDoc, 'ignored_already_checked_in');
      throw error;
    }
    await resolveSignal(db, signalDoc, 'processed_check_in', { attendanceId: attendanceRef.id });
    if (deduction.fraction > 0) {
      await writeHrNotification(db, 'خصم تأخير بانتظار مراجعة HR', `${user.displayName || user.employeeId}: ${deduction.label} (${deduction.amount.toFixed(2)} ${deduction.currency}).`, { attendanceId: attendanceRef.id });
    }
    return;
  }
  if (signal.event !== 'exit') return resolveSignal(db, signalDoc, 'rejected_event');
  // Field missions and approved permissions have already been loaded above.
  // Neither an expected absence nor the configured company break should create
  // a location-leaving alert.  An alert is informational and never changes
  // attendance, pay, or an employee's approval status.
  const hasActiveAttendance = attendance.exists &&
    Boolean(attendance.data()?.checkInTime) &&
    !attendance.data()?.checkOutTime;
  const period = hasActiveAttendance && !fieldAssignment && activeWorkingPeriod({
    nowMinutes: signalTime.minutes,
    workTimes: times,
    permissions: todaysPermissions,
    policy,
  });
  let exitAlert = null;
  if (period) {
    exitAlert = await createLocationExitAlert({
      db,
      userDoc,
      user,
      signal,
      signalTime,
      capturedAt,
      location,
      period,
    });
  }
  // Check-out is deliberately fail-closed. This decision happens before an
  // attendance read/write so an off policy cannot create a hidden checkout.
  if (checkoutPolicy?.enabled !== true) {
    return resolveSignal(db, signalDoc, 'ignored_checkout_policy_disabled', {
      checkoutPolicyRevision: Number(checkoutPolicy?.revision || 0),
      locationExitAlertId: exitAlert?.alertId || null,
    });
  }
  if (!attendance.exists || !attendance.data()?.checkInTime) return resolveSignal(db, signalDoc, 'ignored_without_check_in');
  if (attendance.data()?.checkOutTime) return resolveSignal(db, signalDoc, 'ignored_already_checked_out');
  if (fieldAssignment?.requiresCheckout === false) return resolveSignal(db, signalDoc, 'ignored_field_assignment_no_checkout');
  const exception = activeReturnException({
    nowMinutes: signalTime.minutes,
    permissions: todaysPermissions,
    workTimes: times,
    policy,
  });
  const dueAt = returnGraceDeadline({
    now: capturedAt,
    nowMinutes: signalTime.minutes,
    exception,
    policy,
  });
  const graceRef = db.collection('autoAttendanceReturnGraces').doc(`${userDoc.id}_${signalTime.dateKey}`);
  await graceRef.set({
    userId: userDoc.id,
    employeeId: user.employeeId || '',
    attendanceId: attendanceRef.id,
    date: signalTime.dateKey,
    status: 'pending',
    dueAt: admin.firestore.Timestamp.fromDate(dueAt),
    exitAt: admin.firestore.Timestamp.fromDate(capturedAt),
    locationId: signal.locationId,
    locationName: location.name || signal.locationName || '',
    source: signal.source,
    exceptionReason: exception?.reason || null,
    returnGraceMinutes: Math.round((dueAt.getTime() - capturedAt.getTime()) / 60000),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await resolveSignal(db, signalDoc, exception ? 'pending_return_after_exception' : 'pending_return_grace', {
    attendanceId: attendanceRef.id,
    returnGraceDueAt: admin.firestore.Timestamp.fromDate(dueAt),
    locationExitAlertId: exitAlert?.alertId || null,
  });
}

async function processExpiredReturnGraces(db, checkoutPolicy, now = new Date()) {
  if (checkoutPolicy?.enabled !== true) return { found: 0, processed: 0 };
  const pending = await db.collection('autoAttendanceReturnGraces')
    .where('status', '==', 'pending')
    .limit(100)
    .get();
  let processed = 0;
  for (const graceDoc of pending.docs) {
    const grace = graceDoc.data();
    const dueAt = grace.dueAt?.toDate?.();
    if (!(dueAt instanceof Date) || dueAt > now) continue;
    if (!grace.attendanceId) {
      await graceDoc.ref.update({
        status: 'invalid_without_attendance',
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      continue;
    }
    const attendanceRef = db.collection('attendance').doc(String(grace.attendanceId || ''));
    const attendance = await attendanceRef.get();
    if (!attendance.exists || attendance.data()?.checkOutTime) {
      await graceDoc.ref.update({ status: 'resolved_without_checkout', resolvedAt: admin.firestore.FieldValue.serverTimestamp() });
      continue;
    }
    const checkIn = attendance.data().checkInTime?.toDate?.();
    await attendanceRef.update({
      checkOutTime: admin.firestore.Timestamp.fromDate(dueAt),
      localCheckOutTime: admin.firestore.Timestamp.fromDate(dueAt),
      totalWorkHours: checkIn instanceof Date ? Math.max(0, (dueAt.getTime() - checkIn.getTime()) / 3600000) : 0,
      checkOutAutomatic: true,
      checkOutAttendanceSource: 'return_grace_expired',
      checkOutReason: grace.exceptionReason ? 'return_grace_expired_after_exception' : 'return_grace_expired',
      returnGraceEvidenceId: graceDoc.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await graceDoc.ref.update({ status: 'checked_out', processedAt: admin.firestore.FieldValue.serverTimestamp() });
    processed++;
  }
  return { found: pending.size, processed };
}

async function processAutomaticAttendance() {
  initializeFirebase();
  const db = admin.firestore();
  const now = cairoParts();
  const signals = await db.collection('autoAttendanceSignals')
    .where('status', '==', 'pending')
    .limit(100)
    .get();
  const securityDoc = await db.collection('publicConfig').doc('appSecurity').get();
  if (securityDoc.data()?.automaticAttendanceEnabled !== true) {
    for (const signal of signals.docs) {
      await resolveSignal(db, signal, 'rejected_security_disabled');
    }
    return {
      found: signals.size,
      processed: signals.size,
      failed: 0,
      date: now.dateKey,
      automaticAttendanceEnabled: false,
    };
  }
  // An automatic checkout may be due even when the phone has not sent a new
  // geofence event. Process the durable grace queue on every scheduler tick.
  const checkoutPolicy = await loadCheckoutPolicy(db);
  if (signals.empty) {
    const graceResult = await processExpiredReturnGraces(db, checkoutPolicy, new Date());
    return {
      found: 0,
      processed: 0,
      failed: 0,
      date: now.dateKey,
      checkoutEnabled: checkoutPolicy.enabled,
      checkoutPolicyRevision: checkoutPolicy.revision,
      returnGrace: graceResult,
    };
  }
  // Company policy is needed only when an actual geofence signal exists.
  // Avoid one unnecessary policy read on every five-minute scheduler tick.
  const companyDoc = await db.collection('companies').doc('zawolf').get();
  const multiLocationFlag = securityDoc.data()?.attendance_multi_location_v1;
  let processed = 0;
  let failed = 0;
  for (const signal of signals.docs) {
    try {
      const signalUid = String(signal.data()?.userId || '');
      const multiLocationEnabled = multiLocationFlag === true ||
        securityDoc.data()?.attendanceMultiLocationEnabled === true ||
        (multiLocationFlag?.enabled === true && (
          multiLocationFlag.everyone === true ||
          (Array.isArray(multiLocationFlag.actorIds) &&
            multiLocationFlag.actorIds.map(String).includes(signalUid))
        ));
      await processSignal(
        db,
        signal,
        companyDoc.data() || {},
        now,
        checkoutPolicy,
        multiLocationEnabled,
      );
      processed++;
    } catch (error) {
      failed++;
      console.error(`Automatic attendance signal ${signal.id} failed:`, error);
      await resolveSignal(db, signal, 'failed', { error: String(error.message || error).slice(0, 500) });
    }
  }
  const graceResult = await processExpiredReturnGraces(db, checkoutPolicy, new Date());
  return {
    found: signals.size,
    processed,
    failed,
    date: now.dateKey,
    checkoutEnabled: checkoutPolicy.enabled,
    checkoutPolicyRevision: checkoutPolicy.revision,
    returnGrace: graceResult,
  };
}

if (require.main === module) {
  processAutomaticAttendance().then((result) => {
    console.log('Automatic attendance processing complete:', result);
    process.exit(0);
  }).catch((error) => {
    console.error('Automatic attendance processing failed:', error);
    process.exit(1);
  });
}

module.exports = {
  deductionFor,
  effectiveTimes,
  activeReturnException,
  activeWorkingPeriod,
  createLocationExitAlert,
  returnGraceDeadline,
  haversineMeters,
  isWorkDay,
  processAutomaticAttendance,
  processSignal,
  processExpiredReturnGraces,
};
