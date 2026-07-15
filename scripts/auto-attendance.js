const admin = require('firebase-admin');
const {
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');

installFirestoreCompatibility(admin);

const CAIRO_TIME_ZONE = 'Africa/Cairo';
const MAX_SIGNAL_AGE_MS = 15 * 60 * 1000;
const MAX_LOCATION_ACCURACY_METERS = 25;

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

async function writeHrNotification(db, title, body, data) {
  const hrUsers = await db.collection('users').where('isActive', '==', true).get();
  const batch = db.batch();
  let count = 0;
  for (const userDoc of hrUsers.docs) {
    const role = userDoc.data().role;
    if (role !== 'hr_admin' && role !== 'super_admin') continue;
    const notification = db.collection('notifications').doc(userDoc.id).collection('items').doc();
    batch.set(notification, {
      notificationId: notification.id,
      type: 'salary_deduction_pending', title, body, data,
      isRead: false, pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(userDoc.ref, { unreadNotifications: admin.firestore.FieldValue.increment(1) });
    count++;
  }
  if (count) await batch.commit();
}

async function resolveSignal(db, signalDoc, outcome, extra = {}) {
  await signalDoc.ref.update({
    status: outcome,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  });
}

async function processSignal(db, signalDoc, company, now) {
  const signal = signalDoc.data();
  const capturedAt = signal.createdAt?.toDate?.();
  if (!(capturedAt instanceof Date) || Date.now() - capturedAt.getTime() > MAX_SIGNAL_AGE_MS || capturedAt.getTime() - Date.now() > 60 * 1000) {
    return resolveSignal(db, signalDoc, 'ignored_stale');
  }
  if (!['android_geofence', 'ios_region'].includes(signal.source)) {
    return resolveSignal(db, signalDoc, 'rejected_source');
  }
  // The server timestamp is the authoritative work time. The dispatcher may
  // run a minute later, so never calculate a shift from the worker's clock.
  const signalTime = cairoParts(capturedAt);
  const [userDoc, locationDoc, dayOffDoc] = await Promise.all([
    db.collection('users').doc(signal.userId).get(),
    db.collection('locations').doc(signal.locationId).get(),
    db.collection('companyDayOffs').doc(signalTime.dateKey).get(),
  ]);
  if (!userDoc.exists || !locationDoc.exists) return resolveSignal(db, signalDoc, 'rejected_account_or_location');
  const user = userDoc.data();
  const location = locationDoc.data();
  if (!user.isActive || user.employeeId !== signal.employeeId || user.locationId !== signal.locationId || user.registeredAttendanceDeviceId !== signal.deviceId || !location.isActive) {
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
  if (!Number.isFinite(accuracy) || accuracy <= 0 || accuracy > MAX_LOCATION_ACCURACY_METERS || !Number.isFinite(distance) || distance > radius) {
    return resolveSignal(db, signalDoc, 'rejected_location', { accuracyMeters: accuracy, distanceMeters: distance, allowedRadiusMeters: radius });
  }
  const policy = company.attendancePolicy || company || {};
  const times = effectiveTimes(user, policy, todaysPermissions);
  // The dispatcher can run after midnight while processing an event captured
  // shortly before it. The attendance date must follow the validated signal.
  const attendanceRef = db.collection('attendance').doc(`${userDoc.id}_${signalTime.dateKey}`);
  const attendance = await attendanceRef.get();
  if (signal.event === 'enter') {
    const opensAt = parseMinutes(policy.checkInOpenTime, 7 * 60);
    if (signalTime.minutes < opensAt) return resolveSignal(db, signalDoc, 'ignored_before_check_in_open');
    if (attendance.exists && attendance.data()?.checkInTime) return resolveSignal(db, signalDoc, 'ignored_already_checked_in');
    const deduction = deductionFor(signalTime.minutes, times.start, policy, user.baseMonthlySalary, user.salaryCurrency);
    await attendanceRef.set({
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
    }, { merge: true });
    await resolveSignal(db, signalDoc, 'processed_check_in', { attendanceId: attendanceRef.id });
    if (deduction.fraction > 0) {
      await writeHrNotification(db, 'خصم تأخير بانتظار مراجعة HR', `${user.displayName || user.employeeId}: ${deduction.label} (${deduction.amount.toFixed(2)} ${deduction.currency}).`, { attendanceId: attendanceRef.id });
    }
    return;
  }
  if (signal.event !== 'exit') return resolveSignal(db, signalDoc, 'rejected_event');
  if (!attendance.exists || !attendance.data()?.checkInTime) return resolveSignal(db, signalDoc, 'ignored_without_check_in');
  if (attendance.data()?.checkOutTime) return resolveSignal(db, signalDoc, 'ignored_already_checked_out');
  if (fieldAssignment?.requiresCheckout === false) return resolveSignal(db, signalDoc, 'ignored_field_assignment_no_checkout');
  const latestCheckout = parseMinutes(policy.latestCheckoutTime, 23 * 60);
  if (signalTime.minutes < times.end) return resolveSignal(db, signalDoc, 'ignored_before_checkout_time');
  if (signalTime.minutes > latestCheckout) return resolveSignal(db, signalDoc, 'ignored_after_checkout_deadline');
  const checkIn = attendance.data().checkInTime.toDate();
  await attendanceRef.update({
    checkOutTime: admin.firestore.Timestamp.fromDate(capturedAt),
    localCheckOutTime: admin.firestore.Timestamp.fromDate(capturedAt),
    checkOutLocation: new admin.firestore.GeoPoint(Number(signal.latitude), Number(signal.longitude)),
    totalWorkHours: Math.max(0, (capturedAt.getTime() - checkIn.getTime()) / 3600000),
    checkOutAutomatic: true, checkOutAttendanceSource: signal.source,
    checkOutDeviceId: signal.deviceId, checkOutDeviceLabel: signal.deviceLabel || '',
    checkoutLocationAccuracyMeters: accuracy, checkoutLocationDistanceMeters: distance,
    checkoutLocationAllowedRadiusMeters: radius, checkoutLocationMocked: false,
    checkoutLocationCapturedOffline: false, checkoutSecurityReviewStatus: 'none',
    checkoutLocationRiskLevel: 'low', checkoutLocationRiskReasons: [],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await resolveSignal(db, signalDoc, 'processed_check_out', { attendanceId: attendanceRef.id });
}

async function processAutomaticAttendance() {
  initializeFirebase();
  const db = admin.firestore();
  const now = cairoParts();
  const signals = await db.collection('autoAttendanceSignals')
    .where('status', '==', 'pending')
    .limit(100)
    .get();
  if (signals.empty) {
    return { found: 0, processed: 0, failed: 0, date: now.dateKey };
  }
  // Company policy is needed only when an actual geofence signal exists.
  // Avoid one unnecessary policy read on every five-minute scheduler tick.
  const companyDoc = await db.collection('companies').doc('zawolf').get();
  let processed = 0;
  let failed = 0;
  for (const signal of signals.docs) {
    try {
      await processSignal(db, signal, companyDoc.data() || {}, now);
      processed++;
    } catch (error) {
      failed++;
      console.error(`Automatic attendance signal ${signal.id} failed:`, error);
      await resolveSignal(db, signal, 'failed', { error: String(error.message || error).slice(0, 500) });
    }
  }
  return { found: signals.size, processed, failed, date: now.dateKey };
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

module.exports = { deductionFor, effectiveTimes, haversineMeters, isWorkDay, processAutomaticAttendance };
