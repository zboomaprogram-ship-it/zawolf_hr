const admin = require('firebase-admin');
const { installFirestoreCompatibility } = require('./firebase-service-account');
installFirestoreCompatibility(admin);

// 1. Initialize Firebase Admin
let serviceAccount;
try {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} catch (e) {
  console.error('Error parsing FIREBASE_SERVICE_ACCOUNT secret. Please ensure it is set correctly in GitHub Secrets.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const db = admin.firestore();

// Helper: convert Firestore Timestamp to YYYY-MM-DD string in Cairo time
function timestampToDateStr(ts) {
  if (!ts) return null;
  let date;
  if (ts.toDate) {
    date = ts.toDate(); // Firestore Timestamp
  } else if (ts instanceof Date) {
    date = ts;
  } else if (typeof ts === 'string') {
    return ts; // Already a string
  } else {
    return null;
  }
  const options = { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' };
  return new Intl.DateTimeFormat('en-CA', options).format(date);
}

function cairoDateStr(date) {
  const options = { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' };
  return new Intl.DateTimeFormat('en-CA', options).format(date);
}

function addDays(date, days) {
  const copy = new Date(date);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function parseMinutes(timeStr, fallbackMinutes) {
  if (!timeStr || typeof timeStr !== 'string') return fallbackMinutes;
  const parts = timeStr.split(':').map(Number);
  if (parts.length < 2 || Number.isNaN(parts[0]) || Number.isNaN(parts[1])) {
    return fallbackMinutes;
  }
  return (parts[0] * 60) + parts[1];
}

function timeFromMinutes(totalMinutes) {
  const bounded = Math.max(0, Math.min(23 * 60 + 59, totalMinutes));
  const hours = Math.floor(bounded / 60);
  const minutes = bounded % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function minutesSinceMidnight(date, timeZone = 'Africa/Cairo') {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const hour = Number(parts.find(part => part.type === 'hour')?.value || 0);
  const minute = Number(parts.find(part => part.type === 'minute')?.value || 0);
  return (hour * 60) + minute;
}

function evaluateLateArrival(arrivalDate, effectiveStartTime, policy) {
  const startMinutes = parseMinutes(effectiveStartTime, 9 * 60);
  const arrivalMinutes = minutesSinceMidnight(arrivalDate);
  const lateMinutes = Math.max(0, arrivalMinutes - startMinutes);
  const grace = policy.graceMinutes ?? 15;
  const quarterUntil = policy.quarterDayUntilMinutes ?? 30;
  const halfUntil = policy.halfDayUntilMinutes ?? 60;
  if (lateMinutes <= grace) {
    return { fraction: 0, code: 'none', label: 'لا يوجد خصم', status: 'present', lateMinutes, isLate: false };
  }
  if (lateMinutes <= quarterUntil) {
    return { fraction: 0.25, code: 'quarter_day', label: 'خصم ربع يوم', status: 'late_quarter_day', lateMinutes, isLate: true };
  }
  if (lateMinutes <= halfUntil) {
    return { fraction: 0.5, code: 'half_day', label: 'خصم نصف يوم', status: 'late_half_day', lateMinutes, isLate: true };
  }
  return { fraction: 1, code: 'full_day', label: 'خصم يوم كامل', status: 'late_full_day', lateMinutes, isLate: true };
}

async function runDailyTasks() {
  console.log('Starting daily tasks...');
  
  // By default process yesterday, because absence and missed-checkout decisions
  // must happen after the workday has fully ended.
  const now = new Date();
  const cairoHour = Number(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Cairo',
    hour: '2-digit',
    hourCycle: 'h23',
  }).format(now));
  const requiredCairoHour = Number(process.env.REQUIRE_CAIRO_HOUR || -1);
  if (requiredCairoHour >= 0 && cairoHour !== requiredCairoHour) {
    console.log(
      `Skipping scheduled daily tasks at Cairo hour ${cairoHour}; expected ${requiredCairoHour}.`,
    );
    return;
  }
  const todayCairoStr = cairoDateStr(now);
  const requestedDate = process.env.PROCESS_DATE;
  const todayStr = requestedDate || cairoDateStr(addDays(now, -1));
  if (!requestedDate && todayStr >= todayCairoStr) {
    console.log('Skipping current day processing. Daily tasks only process completed workdays.');
    process.exit(0);
  }
  console.log(`Processing completed workday: ${todayStr}`);

  // These dates were administratively reset. Keep the nightly job from
  // recreating absence, lateness, or deduction records for them.
  const attendanceAmnestyDates = new Set(
    (process.env.ATTENDANCE_AMNESTY_DATES || '2026-07-18,2026-07-19')
      .split(',')
      .map(value => value.trim())
      .filter(Boolean),
  );
  const skipAttendanceProcessing = attendanceAmnestyDates.has(todayStr);
  if (skipAttendanceProcessing) {
    console.log(`Attendance amnesty is active for ${todayStr}; attendance processing will be skipped.`);
  }

  // Get JS Day 0-6 in Cairo time
  const jsDayOptions = { timeZone: 'Africa/Cairo', weekday: 'short' };
  const targetNoonUtc = new Date(`${todayStr}T12:00:00.000Z`);
  const weekdayShort = new Intl.DateTimeFormat('en-US', jsDayOptions).format(targetNoonUtc);
  const weekdayMap = { 'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6 };
  const jsDay = weekdayMap[weekdayShort];
  
  // Map JS Day to Dart's DateTime.weekday (1=Mon, 7=Sun)
  const dartWeekday = jsDay === 0 ? 7 : jsDay;

  // Check if today is a company day off
  const dayOffSnap = await db.collection('companyDayOffs').doc(todayStr).get();
  if (dayOffSnap.exists) {
    const dayOffData = dayOffSnap.data();
    if (dayOffData.isActive) {
      console.log(`Today is a company holiday: ${dayOffData.title}. Skipping absence tracking.`);
      process.exit(0);
    }
  }

  // Fetch all approved leaves to check who is on vacation today
  // CRITICAL: startDate/endDate are stored as Firestore Timestamps, not strings!
  const leavesSnap = await db.collection('leaves').where('status', '==', 'approved').get();
  const activeLeavesByUserId = {};
  leavesSnap.docs.forEach(doc => {
    const leave = doc.data();
    const startStr = timestampToDateStr(leave.startDate);
    const endStr = timestampToDateStr(leave.endDate);
    if (startStr && endStr && startStr <= todayStr && endStr >= todayStr) {
      activeLeavesByUserId[leave.userId] = { ...leave, leaveId: doc.id };
    }
  });

  // Fetch all approved permissions for today
  const permsSnap = await db.collection('permissions')
    .where('status', '==', 'approved')
    .where('requestDate', '==', todayStr)
    .get();
  const approvedPermsByUserId = {};
  permsSnap.docs.forEach(doc => {
    const perm = doc.data();
    if (!approvedPermsByUserId[perm.userId]) approvedPermsByUserId[perm.userId] = {};
    approvedPermsByUserId[perm.userId][perm.permissionType] = perm;
  });

  // Fetch all active employees
  const usersSnap = await db.collection('users').where('isActive', '==', true).get();
  console.log(`Found ${usersSnap.size} active users.`);

  // Review notifications should go to HR/super admins, not the employee who was deducted.
  const reviewerIds = new Set();
  const hrSnap = await db
    .collection('users')
    .where('role', '==', 'hr_admin')
    .where('isActive', '==', true)
    .get();
  hrSnap.docs.forEach(doc => reviewerIds.add(doc.id));
  const hrManagerSnap = await db
    .collection('users')
    .where('role', '==', 'hr_manager')
    .where('isActive', '==', true)
    .get();
  hrManagerSnap.docs.forEach(doc => reviewerIds.add(doc.id));
  const superSnap = await db
    .collection('users')
    .where('role', '==', 'super_admin')
    .where('isActive', '==', true)
    .get();
  superSnap.docs.forEach(doc => reviewerIds.add(doc.id));
  console.log(`Found ${reviewerIds.size} HR/HR-manager/super-admin reviewers for deduction notifications.`);

  // Load attendance policy
  let payrollWorkDaysPerMonth = 26;
  const policy = {
    defaultStartTime: '09:00',
    defaultEndTime: '17:00',
    graceMinutes: 15,
    quarterDayUntilMinutes: 30,
    halfDayUntilMinutes: 60,
  };
  try {
    const companySnap = await db.collection('companies').doc('zawolf').get();
    if (companySnap.exists) {
      const data = companySnap.data();
      const loadedPolicy = data.attendancePolicy || data;
      Object.assign(policy, loadedPolicy);
      if (loadedPolicy.payrollWorkDaysPerMonth) {
        payrollWorkDaysPerMonth = parseInt(loadedPolicy.payrollWorkDaysPerMonth, 10);
      }
    }
  } catch (e) {
    console.warn('Could not load company policy, defaulting to 26 payroll days.', e);
  }

  let absentsCreated = 0;
  let leavesCreated = 0;
  let updatesApplied = 0;
  const missedCheckoutEmployees = [];

  // Firestore batches have a 500 operation limit, so we chunk
  let batch = db.batch();
  let batchOps = 0;
  const BATCH_LIMIT = 450; // stay safely under 500

  async function commitIfNeeded() {
    if (batchOps >= BATCH_LIMIT) {
      await batch.commit();
      console.log(`Committed batch of ${batchOps} operations.`);
      batch = db.batch();
      batchOps = 0;
    }
  }

  async function notifyReviewers(type, title, body, data) {
    for (const reviewerId of reviewerIds) {
      const notifRef = db.collection('notifications').doc(reviewerId).collection('items').doc();
      batch.set(notifRef, {
        notificationId: notifRef.id,
        type,
        title,
        body,
        data: data || {},
        isRead: false,
        pushSent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchOps++;
      batch.update(db.collection('users').doc(reviewerId), {
        unreadNotifications: admin.firestore.FieldValue.increment(1)
      });
      batchOps++;
      await commitIfNeeded();
    }
  }

  async function markOverdueTasks() {
    const overdueSnap = await db
      .collection('tasks')
      .where('status', 'in', ['new', 'in_progress'])
      .where('dueDate', '<', admin.firestore.Timestamp.fromDate(now))
      .get();

    let overdueTasks = 0;
    for (const taskDoc of overdueSnap.docs) {
      const task = taskDoc.data();
      const assigneeId = task.assigneeId;
      batch.update(taskDoc.ref, {
        status: 'late',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchOps++;
      overdueTasks++;

      if (assigneeId) {
        const title = 'مهمة متأخرة';
        const body = `المهمة "${task.title || ''}" تجاوزت آخر موعد للتنفيذ.`;
        const notifRef = db.collection('notifications').doc(assigneeId).collection('items').doc();
        batch.set(notifRef, {
          notificationId: notifRef.id,
          type: 'task_overdue',
          title,
          body,
          data: { taskId: taskDoc.id },
          isRead: false,
          pushSent: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batchOps++;
        batch.update(db.collection('users').doc(assigneeId), {
          unreadNotifications: admin.firestore.FieldValue.increment(1)
        });
        batchOps++;
      }

      await commitIfNeeded();
    }
    console.log(`Marked ${overdueTasks} overdue tasks.`);
  }

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data();
    const userId = userDoc.id;

    if (skipAttendanceProcessing) {
      continue;
    }

    // Check if today is a custom day off for the user
    let isOffDay = false;
    if (user.workSchedule && Array.isArray(user.workSchedule.workDays)) {
      if (!user.workSchedule.workDays.includes(dartWeekday)) {
        isOffDay = true;
      }
    } else {
      // Default to Friday (5) off if no custom schedule
      if (dartWeekday === 5) {
        isOffDay = true;
      }
    }

    // Check attendance log for today
    const attendanceId = `${userId}_${todayStr}`;
    const attendanceRef = db.collection('attendance').doc(attendanceId);
    const attendanceSnap = await attendanceRef.get();

    if (!attendanceSnap.exists) {
      if (isOffDay) {
        continue;
      }

      if (activeLeavesByUserId[userId]) {
        const activeLeave = activeLeavesByUserId[userId];
        const requiresFullDaySalaryDeduction =
          activeLeave.leaveType === 'unpaid' ||
          activeLeave.requiresFullDaySalaryDeduction === true;
        const baseSalary = user.baseMonthlySalary || 0;
        const unpaidLeaveAmount = requiresFullDaySalaryDeduction
          ? baseSalary / payrollWorkDaysPerMonth
          : 0;

        // Create on-leave record
        batch.set(attendanceRef, {
          userId: userId,
          employeeId: user.employeeId || '',
          employeeName: user.displayName || '',
          locationId: user.locationId || '',
          locationName: user.locationName || '',
          managerId: user.managerId || '',
          date: todayStr,
          checkInTime: null,
          checkInLocation: new admin.firestore.GeoPoint(0, 0),
          isWithinGeofence: true,
          isLate: false,
          lateMinutes: 0,
          // Older clients scan every historical row without a checkout before
          // they create today's attendance. A rejected zero-value sentinel
          // prevents an approved leave row from being mistaken for a missed
          // checkout while remaining excluded from payroll calculations.
          salaryDeductionFraction: requiresFullDaySalaryDeduction ? 1 : 0.25,
          salaryDeductionAmount: unpaidLeaveAmount,
          salaryCurrency: user.salaryCurrency || 'EGP',
          salaryDeductionCode: requiresFullDaySalaryDeduction
            ? 'unpaid_leave_full_day'
            : 'non_attendance_history_ignored',
          salaryDeductionLabel: requiresFullDaySalaryDeduction
            ? 'خصم يوم كامل - إجازة بدون راتب'
            : 'لا يوجد خصم - سجل إجازة',
          salaryDeductionApprovalStatus: requiresFullDaySalaryDeduction
            ? 'pending_hr'
            : 'rejected',
          biometricVerified: false,
          status: 'on-leave',
        });
        batchOps++;
        leavesCreated++;
        if (requiresFullDaySalaryDeduction) {
          await notifyReviewers(
            'salary_deduction_pending',
            'خصم إجازة بدون راتب بانتظار مراجعة HR',
            `${user.displayName}: خصم يوم كامل عن إجازة بدون راتب بتاريخ ${todayStr} (${unpaidLeaveAmount.toFixed(2)} ${user.salaryCurrency || 'EGP'}).`,
            { attendanceId: attendanceId, leaveId: activeLeave.leaveId || '' }
          );
        }
      } else {
        // Create absent record
        const salaryDeductionFraction = 1.0;
        const baseSalary = user.baseMonthlySalary || 0;
        const amount = (baseSalary / payrollWorkDaysPerMonth) * salaryDeductionFraction;

        batch.set(attendanceRef, {
          userId: userId,
          employeeId: user.employeeId || '',
          employeeName: user.displayName || '',
          locationId: user.locationId || '',
          locationName: user.locationName || '',
          managerId: user.managerId || '',
          date: todayStr,
          checkInTime: null,
          checkInLocation: new admin.firestore.GeoPoint(0, 0),
          isWithinGeofence: true,
          isLate: false,
          lateMinutes: 0,
          salaryDeductionFraction: salaryDeductionFraction,
          salaryDeductionAmount: amount,
          salaryCurrency: user.salaryCurrency || 'EGP',
          salaryDeductionCode: 'absent',
          salaryDeductionLabel: 'غياب',
          salaryDeductionApprovalStatus: 'pending_hr',
          biometricVerified: false,
          status: 'absent',
        });
        batchOps++;
        absentsCreated++;

        await notifyReviewers(
          'salary_deduction_pending',
          'غياب بانتظار مراجعة HR',
          `${user.displayName}: غياب عن يوم ${todayStr} (${amount.toFixed(2)} ${user.salaryCurrency || 'EGP'}).`,
          { attendanceId: attendanceId }
        );
      }
    } else {
      const log = attendanceSnap.data();
      const updates = {};
      
      // 1. Recalculate late arrival against approved late-arrival permission.
      if (log.checkInTime && log.salaryDeductionCode !== 'absent') {
        const latePerm = approvedPermsByUserId[userId]?.['late_arrival'];
        const baseStart = user.workSchedule?.startTime || policy.defaultStartTime || '09:00';
        const startMinutes = parseMinutes(baseStart, 9 * 60) + (latePerm?.durationMinutes || 0);
        const effectiveStart = timeFromMinutes(startMinutes);
        const deduction = evaluateLateArrival(log.checkInTime.toDate ? log.checkInTime.toDate() : log.checkInTime, effectiveStart, policy);
        const amount = ((user.baseMonthlySalary || 0) / payrollWorkDaysPerMonth) * deduction.fraction;
        if (
          deduction.code !== log.salaryDeductionCode ||
          deduction.lateMinutes !== log.lateMinutes ||
          deduction.status !== log.status
        ) {
          Object.assign(updates, {
            isLate: deduction.isLate,
            lateMinutes: deduction.lateMinutes,
            salaryDeductionFraction: deduction.fraction,
            salaryDeductionAmount: amount,
            salaryDeductionCode: deduction.code,
            salaryDeductionLabel: deduction.label,
            salaryDeductionApprovalStatus: deduction.fraction > 0 ? 'pending_hr' : 'none',
            status: deduction.status,
          });
        }
      }

      // 2. Check if they forgot to checkout. The job runs after the completed day,
      // so employees had until 11 PM to check out from the location.
      if (log.checkInTime && !log.checkOutTime) {
        const wasAlreadyDetected = Boolean(log.salaryDeductionDetectedAt);
        const currentFraction = updates.salaryDeductionFraction !== undefined ? updates.salaryDeductionFraction : log.salaryDeductionFraction;

        if (!wasAlreadyDetected) {
          missedCheckoutEmployees.push({
            userId,
            attendanceId,
            displayName: user.displayName || user.employeeId || userId,
          });
        }

        if (!wasAlreadyDetected && currentFraction < 0.25) {
          const salaryDeductionFraction = 0.25;
          const baseSalary = user.baseMonthlySalary || 0;
          const amount = (baseSalary / payrollWorkDaysPerMonth) * salaryDeductionFraction;

          Object.assign(updates, {
            salaryDeductionFraction: salaryDeductionFraction,
            salaryDeductionAmount: amount,
            salaryDeductionCode: 'missed_checkout_quarter_day',
            salaryDeductionLabel: 'خصم ربع يوم - عدم تسجيل الانصراف',
            salaryDeductionApprovalStatus: 'pending_hr',
            salaryDeductionDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else if (!wasAlreadyDetected) {
          Object.assign(updates, {
            salaryDeductionDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } else if (log.checkOutTime && log.salaryDeductionCode === 'early_checkout_quarter_day') {
        // 3. Handle early checkout permission. Required checkout time is shifted earlier.
        const earlyPerm = approvedPermsByUserId[userId]?.['early_leave'];
        const baseEnd = user.workSchedule?.endTime || policy.defaultEndTime || '17:00';
        const allowedCheckoutMinutes = parseMinutes(baseEnd, 17 * 60) - (earlyPerm?.durationMinutes || 0);
        const checkoutDate = log.checkOutTime.toDate ? log.checkOutTime.toDate() : log.checkOutTime;
        if (minutesSinceMidnight(checkoutDate) >= allowedCheckoutMinutes) {
          updates.salaryDeductionFraction = 0;
          updates.salaryDeductionAmount = 0;
          updates.salaryDeductionCode = 'none';
          updates.salaryDeductionLabel = 'لا يوجد خصم';
          updates.salaryDeductionApprovalStatus = 'none';
        }
      }

      if (Object.keys(updates).length > 0) {
        batch.update(attendanceRef, updates);
        batchOps++;
        updatesApplied++;
      }
    }

    await commitIfNeeded();
  }

  if (missedCheckoutEmployees.length > 0) {
    const visibleNames = missedCheckoutEmployees
      .slice(0, 5)
      .map(employee => employee.displayName)
      .join('، ');
    const remaining = missedCheckoutEmployees.length - 5;
    const remainingLabel = remaining > 0 ? `، و${remaining} آخرين` : '';
    await notifyReviewers(
      'salary_deduction_pending',
      'مراجعة عدم تسجيل الانصراف',
      `${missedCheckoutEmployees.length} موظف لم يسجلوا الانصراف عن يوم ${todayStr}: ${visibleNames}${remainingLabel}.`,
      {
        route: '/manager/requests',
        date: todayStr,
        deductionType: 'missed_checkout',
        employeeCount: missedCheckoutEmployees.length,
      },
    );
  }

  await markOverdueTasks();

  if (batchOps > 0) {
    await batch.commit();
    console.log(`Final batch committed with ${batchOps} operations.`);
  }

  console.log(`Done! Created ${absentsCreated} absences, ${leavesCreated} on-leave records, updated ${updatesApplied} shifts.`);
}

runDailyTasks()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Error running daily tasks:', error);
    process.exit(1);
  });
