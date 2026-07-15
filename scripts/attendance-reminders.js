const admin = require('firebase-admin');
const {
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');
installFirestoreCompatibility(admin);

const CAIRO_TIME_ZONE = 'Africa/Cairo';
// The Hostinger process scans every five minutes. A ten-minute window covers
// a delayed scan while the run-document prevents duplicate reminders.
const REMINDER_WINDOW_MINUTES = 10;
// Active employee profiles change rarely during a working day. Reusing them
// for a short period prevents a full users read on every five-minute tick.
const ACTIVE_USERS_CACHE_MS = Math.max(
  15 * 60 * 1000,
  Number(process.env.ATTENDANCE_REMINDER_USERS_CACHE_MS || 60 * 60 * 1000),
);
let activeUsersCache = { expiresAt: 0, users: [] };

function initializeFirebase() {
  const existingApp = getExistingFirebaseApp(admin);
  if (existingApp) return existingApp;

  const serviceAccount = parseFirebaseServiceAccount(
    process.env.FIREBASE_SERVICE_ACCOUNT,
  );

  return admin.initializeApp({
    credential: admin.cert(serviceAccount),
  });
}

function cairoParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: CAIRO_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
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
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) return fallback;
  return Math.max(0, Math.min(1439, hour * 60 + minute));
}

function formatTime(minutes) {
  return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
}

function isReminderScanWindow(nowMinutes, policy) {
  // This avoids reading the full employee list overnight. Companies with an
  // unusual shift can override either value in attendancePolicy in Firestore.
  const start = parseMinutes(policy.reminderScanStartTime, 6 * 60);
  const end = parseMinutes(policy.reminderScanEndTime, 20 * 60);
  return start <= end
    ? nowMinutes >= start && nowMinutes <= end
    : nowMinutes >= start || nowMinutes <= end;
}

function timestampToDateKey(value) {
  if (!value) return null;
  if (typeof value === 'string') {
    const matchedDate = value.match(/^(\d{4}-\d{2}-\d{2})/);
    if (matchedDate) return matchedDate[1];
  }

  const date = typeof value.toDate === 'function' ? value.toDate() : value;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return null;
  return cairoParts(date).dateKey;
}

function isDateWithinLeave(leave, dateKey) {
  const start = timestampToDateKey(leave.startDate);
  const end = timestampToDateKey(leave.endDate);
  return Boolean(start && end && start <= dateKey && dateKey <= end);
}

function isWorkDay(user, cairoWeekday) {
  const weekdayMap = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  const workDays = user.workSchedule?.workDays;
  if (Array.isArray(workDays) && workDays.length) {
    return workDays.includes(weekdayMap[cairoWeekday]);
  }
  return cairoWeekday !== 'Fri';
}

async function loadActiveUsers(db) {
  if (Date.now() < activeUsersCache.expiresAt) {
    return activeUsersCache.users;
  }
  const snapshot = await db.collection('users').where('isActive', '==', true).get();
  activeUsersCache = {
    expiresAt: Date.now() + ACTIVE_USERS_CACHE_MS,
    users: snapshot.docs,
  };
  return activeUsersCache.users;
}

function notificationFor({ kind, startMinutes, endMinutes, hasLatePermission, hasEarlyPermission, reminderLeadMinutes = 10, lateReminderMinutes = 10 }) {
  if (kind === 'check_in_before') {
    const effectiveStart = startMinutes;
    return {
      targetMinutes: Math.max(0, effectiveStart - reminderLeadMinutes),
      title: 'تذكير بتسجيل الحضور',
      body: hasLatePermission
        ? `موعد حضورك المعتمد اليوم الساعة ${formatTime(effectiveStart)}. لا تنسَ تسجيل الحضور.`
        : `موعد بدء الدوام الساعة ${formatTime(effectiveStart)}. لا تنسَ تسجيل الحضور.`,
      type: 'attendance_check_in_reminder',
    };
  }
  if (kind === 'check_in_start') {
    return {
      targetMinutes: startMinutes,
      title: 'حان وقت تسجيل الحضور',
      body: `موعد حضورك المعتمد الآن الساعة ${formatTime(startMinutes)}. سجّل حضورك لتجنب الخصم.`,
      type: 'attendance_check_in_reminder',
    };
  }
  if (kind === 'check_in_late_warning') {
    return {
      targetMinutes: startMinutes + lateReminderMinutes,
      title: 'تنبيه قبل خصم التأخير',
      body: `لم يتم تسجيل حضورك بعد. سجّل الحضور الآن قبل بدء احتساب خصم التأخير.`,
      type: 'attendance_late_warning',
    };
  }
  return {
    targetMinutes: endMinutes,
    title: 'تذكير بتسجيل الانصراف',
    body: hasEarlyPermission
      ? `حان وقت الانصراف المعتمد اليوم الساعة ${formatTime(endMinutes)}. سجّل انصرافك من موقع العمل.`
      : `انتهى الدوام الساعة ${formatTime(endMinutes)}. لا تنسَ تسجيل الانصراف قبل المغادرة.`,
    type: 'attendance_check_out_reminder',
  };
}

async function createReminder(db, { userId, dateKey, kind, notification }) {
  const runId = `${dateKey}_${userId}_${kind}_${notification.targetMinutes}`;
  const runRef = db.collection('attendanceReminderRuns').doc(runId);
  const notificationRef = db.collection('notifications').doc(userId).collection('items').doc();

  try {
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(runRef);
      if (existing.exists) return;
      transaction.create(runRef, {
        userId,
        date: dateKey,
        kind,
        plannedMinute: notification.targetMinutes,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.create(notificationRef, {
        notificationId: notificationRef.id,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        data: { route: '/employee/dashboard', reminderKind: kind, date: dateKey },
        isRead: false,
        pushSent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(db.collection('users').doc(userId), {
        unreadNotifications: admin.firestore.FieldValue.increment(1),
      });
    });
    return true;
  } catch (error) {
    // An already-created run is expected when two schedulers overlap.
    if (error.code === 6 || String(error.message || error).includes('Already exists')) return false;
    throw error;
  }
}

async function queueAttendanceReminders() {
  initializeFirebase();
  const db = admin.firestore();
  const now = cairoParts();
  if (now.weekday === 'Fri') return { queued: 0, skipped: 'friday', date: now.dateKey };

  const [companyDayOff, companySnap] = await Promise.all([
    db.collection('companyDayOffs').doc(now.dateKey).get(),
    db.collection('companies').doc('zawolf').get(),
  ]);
  if (companyDayOff.exists && companyDayOff.data()?.isActive === true) {
    return { queued: 0, skipped: 'company_day_off', date: now.dateKey };
  }
  const policy = companySnap.data()?.attendancePolicy || companySnap.data() || {};
  if (!isReminderScanWindow(now.minutes, policy)) {
    return { queued: 0, skipped: 'outside_reminder_window', date: now.dateKey };
  }

  const [users, leavesSnap, permissionsSnap, fieldAssignmentsSnap] = await Promise.all([
    loadActiveUsers(db),
    db.collection('leaves').where('status', '==', 'approved').get(),
    db.collection('permissions').where('status', '==', 'approved').where('requestDate', '==', now.dateKey).get(),
    db.collection('fieldAssignments').where('status', '==', 'active').where('date', '==', now.dateKey).get(),
  ]);

  const leaveByUser = new Map();
  for (const doc of leavesSnap.docs) {
    const leave = doc.data();
    if (isDateWithinLeave(leave, now.dateKey)) leaveByUser.set(leave.userId, leave);
  }
  const permissionsByUser = new Map();
  for (const doc of permissionsSnap.docs) {
    const permission = doc.data();
    if (!permissionsByUser.has(permission.userId)) permissionsByUser.set(permission.userId, []);
    permissionsByUser.get(permission.userId).push(permission);
  }
  const fieldAssignmentsByUser = new Map();
  for (const doc of fieldAssignmentsSnap.docs) {
    const assignment = doc.data();
    if (!fieldAssignmentsByUser.has(assignment.userId)) fieldAssignmentsByUser.set(assignment.userId, []);
    fieldAssignmentsByUser.get(assignment.userId).push(assignment);
  }

  let queued = 0;
  for (const userDoc of users) {
    const user = userDoc.data();
    if (!isWorkDay(user, now.weekday) || leaveByUser.has(userDoc.id)) continue;

    const permissions = permissionsByUser.get(userDoc.id) || [];
    const fieldAssignments = fieldAssignmentsByUser.get(userDoc.id) || [];
    const late = permissions.find((item) => item.permissionType === 'late_arrival');
    const early = permissions.find((item) => item.permissionType === 'early_leave');
    const baseStart = parseMinutes(user.workSchedule?.startTime, 9 * 60);
    const baseEnd = parseMinutes(user.workSchedule?.endTime, 17 * 60);
    const effectiveStart = late ? baseStart + Number(late.durationMinutes || 0) : baseStart;
    const effectiveEnd = early ? baseEnd - Number(early.durationMinutes || 0) : baseEnd;
    const reminderLeadMinutes = Number(policy.checkInReminderLeadMinutes ?? 10);
    const lateReminderMinutes = Number(policy.checkInLateWarningMinutes ?? 10);

    const plans = [
      { kind: 'check_in_before', notification: notificationFor({ kind: 'check_in_before', startMinutes: effectiveStart, endMinutes: effectiveEnd, hasLatePermission: Boolean(late), hasEarlyPermission: Boolean(early), reminderLeadMinutes, lateReminderMinutes }) },
      { kind: 'check_in_start', notification: notificationFor({ kind: 'check_in_start', startMinutes: effectiveStart, endMinutes: effectiveEnd, hasLatePermission: Boolean(late), hasEarlyPermission: Boolean(early), reminderLeadMinutes, lateReminderMinutes }) },
      { kind: 'check_in_late_warning', notification: notificationFor({ kind: 'check_in_late_warning', startMinutes: effectiveStart, endMinutes: effectiveEnd, hasLatePermission: Boolean(late), hasEarlyPermission: Boolean(early), reminderLeadMinutes, lateReminderMinutes }) },
      { kind: 'check_out', notification: notificationFor({ kind: 'check_out', startMinutes: effectiveStart, endMinutes: effectiveEnd, hasLatePermission: Boolean(late), hasEarlyPermission: Boolean(early) }) },
    ];

    const duePlans = plans.filter((plan) => {
      if (plan.kind === 'check_out' && fieldAssignments.some((item) => item.requiresCheckout === false)) return false;
      return now.minutes >= plan.notification.targetMinutes
        && now.minutes < plan.notification.targetMinutes + REMINDER_WINDOW_MINUTES;
    });
    if (!duePlans.length) continue;

    // Do not read one attendance document per active employee on every scan.
    // Attendance is needed only for an employee with a reminder due now.
    const attendance = await db.collection('attendance').doc(`${userDoc.id}_${now.dateKey}`).get();
    const attendanceData = attendance.exists ? attendance.data() : null;

    for (const plan of duePlans) {
      const isAlreadyDone = plan.kind.startsWith('check_in')
        ? attendanceData?.checkInTime != null
        : attendanceData?.checkOutTime != null || attendanceData?.checkInTime == null;
      if (isAlreadyDone) continue;
      if (await createReminder(db, { userId: userDoc.id, dateKey: now.dateKey, kind: plan.kind, notification: plan.notification })) queued++;
    }
  }
  return { queued, date: now.dateKey, cairoMinute: now.minutes };
}

if (require.main === module) {
  queueAttendanceReminders()
    .then((result) => { console.log('Attendance reminders complete:', result); process.exit(0); })
    .catch((error) => { console.error('Attendance reminders failed:', error); process.exit(1); });
}

module.exports = {
  isWorkDay,
  isReminderScanWindow,
  loadActiveUsers,
  notificationFor,
  queueAttendanceReminders,
};
