const admin = require('firebase-admin');
const { isOneSignalConfigured, sendPushToUsers } = require('./onesignal');

// 1. Initialize Firebase Admin
let serviceAccount;
try {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} catch (e) {
  console.error('Error parsing FIREBASE_SERVICE_ACCOUNT secret. Please ensure it is set correctly in GitHub Secrets.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
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

async function runDailyTasks() {
  console.log('Starting daily tasks...');
  console.log(`OneSignal push sender: ${isOneSignalConfigured() ? 'configured' : 'not configured'}`);
  
  // Get date in Egypt time (GMT+3)
  const options = { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' };
  const formatter = new Intl.DateTimeFormat('en-CA', options);
  
  const now = new Date();
  const todayStr = formatter.format(now);
  console.log(`Processing for date: ${todayStr}`);

  // Get JS Day 0-6 in Cairo time
  const jsDayOptions = { timeZone: 'Africa/Cairo', weekday: 'short' };
  const weekdayShort = new Intl.DateTimeFormat('en-US', jsDayOptions).format(now);
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
      activeLeavesByUserId[leave.userId] = leave;
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
  const superSnap = await db
    .collection('users')
    .where('role', '==', 'super_admin')
    .where('isActive', '==', true)
    .get();
  superSnap.docs.forEach(doc => reviewerIds.add(doc.id));
  console.log(`Found ${reviewerIds.size} HR/super-admin reviewers for deduction notifications.`);

  // Load policy for payrollWorkDaysPerMonth
  let payrollWorkDaysPerMonth = 26;
  try {
    const companySnap = await db.collection('companies').doc('zawolf').get();
    if (companySnap.exists) {
      const data = companySnap.data();
      const policy = data.attendancePolicy || data;
      if (policy.payrollWorkDaysPerMonth) {
        payrollWorkDaysPerMonth = parseInt(policy.payrollWorkDaysPerMonth, 10);
      }
    }
  } catch (e) {
    console.warn('Could not load company policy, defaulting to 26 payroll days.', e);
  }

  let absentsCreated = 0;
  let leavesCreated = 0;
  let updatesApplied = 0;

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
    const pushUserIds = [...reviewerIds];
    for (const reviewerId of reviewerIds) {
      const notifRef = db.collection('notifications').doc(reviewerId).collection('items').doc();
      batch.set(notifRef, {
        notificationId: notifRef.id,
        type,
        title,
        body,
        data: data || {},
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchOps++;
      batch.update(db.collection('users').doc(reviewerId), {
        unreadNotifications: admin.firestore.FieldValue.increment(1)
      });
      batchOps++;
      await commitIfNeeded();
    }
    await sendPushSafely(pushUserIds, title, body, { type, ...(data || {}) });
  }

  async function sendPushSafely(userIds, title, body, data) {
    try {
      const result = await sendPushToUsers(userIds, title, body, data);
      if (result.sent) {
        console.log(`Sent OneSignal push to ${userIds.length} user(s): ${title}`);
      }
    } catch (e) {
      console.warn('OneSignal push failed, Firestore notification was still created.', e.message);
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
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batchOps++;
        batch.update(db.collection('users').doc(assigneeId), {
          unreadNotifications: admin.firestore.FieldValue.increment(1)
        });
        batchOps++;
        await sendPushSafely([assigneeId], title, body, {
          type: 'task_overdue',
          taskId: taskDoc.id,
        });
      }

      await commitIfNeeded();
    }
    console.log(`Marked ${overdueTasks} overdue tasks.`);
  }

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data();
    const userId = userDoc.id;

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
          salaryDeductionFraction: 0,
          salaryDeductionAmount: 0,
          salaryCurrency: user.salaryCurrency || 'EGP',
          salaryDeductionCode: 'none',
          salaryDeductionLabel: 'لا يوجد خصم',
          salaryDeductionApprovalStatus: 'none',
          biometricVerified: false,
          status: 'on-leave',
        });
        batchOps++;
        leavesCreated++;
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
      
      // 1. Handle late arrival forgiveness via permission
      if (log.isLate && log.salaryDeductionFraction > 0 && log.salaryDeductionCode !== 'absent') {
        const perm = approvedPermsByUserId[userId]?.['late_arrival'];
        if (perm) {
           updates.isLate = false;
           updates.salaryDeductionFraction = perm.salaryDeductionFraction || 0;
           updates.salaryDeductionAmount = perm.salaryDeductionAmount || 0;
           updates.salaryDeductionCode = perm.salaryDeductionCode || 'none';
           updates.salaryDeductionLabel = 'مغفور بإذن (تأخير)';
           updates.salaryDeductionApprovalStatus = (perm.salaryDeductionFraction || 0) > 0 ? 'pending_hr' : 'none';
           updates.status = (perm.salaryDeductionFraction || 0) > 0 ? log.status : 'present';
        }
      }

      // 2. Check if they forgot to checkout
      if (log.checkInTime && !log.checkOutTime) {
        const currentFraction = updates.salaryDeductionFraction !== undefined ? updates.salaryDeductionFraction : log.salaryDeductionFraction;
        
        if (currentFraction < 0.25) {
          const salaryDeductionFraction = 0.25;
          const baseSalary = user.baseMonthlySalary || 0;
          const amount = (baseSalary / payrollWorkDaysPerMonth) * salaryDeductionFraction;

          Object.assign(updates, {
            checkOutTime: admin.firestore.FieldValue.serverTimestamp(),
            checkOutLocation: log.checkInLocation,
            localCheckOutTime: admin.firestore.FieldValue.serverTimestamp(),
            totalWorkHours: 0,
            checkOutDeviceId: log.deviceId || 'system_auto_close',
            checkOutDeviceLabel: 'System Auto Close',
            checkOutBiometricVerified: false,
            salaryDeductionFraction: salaryDeductionFraction,
            salaryDeductionAmount: amount,
            salaryDeductionCode: 'missed_checkout_quarter_day',
            salaryDeductionLabel: 'خصم ربع يوم - عدم تسجيل الانصراف',
            salaryDeductionApprovalStatus: 'pending_hr',
            salaryDeductionDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          await notifyReviewers(
            'salary_deduction_pending',
            'خصم عدم تسجيل انصراف بانتظار مراجعة HR',
            `${user.displayName}: خصم ربع يوم - عدم تسجيل الانصراف عن يوم ${todayStr} (${amount.toFixed(2)} ${user.salaryCurrency || 'EGP'}).`,
            { attendanceId: attendanceId }
          );
        } else {
          Object.assign(updates, {
            checkOutTime: admin.firestore.FieldValue.serverTimestamp(),
            checkOutLocation: log.checkInLocation,
            localCheckOutTime: admin.firestore.FieldValue.serverTimestamp(),
            totalWorkHours: 0,
            checkOutDeviceId: log.deviceId || 'system_auto_close',
            checkOutDeviceLabel: 'System Auto Close',
            checkOutBiometricVerified: false,
          });
        }
      } else if (log.checkOutTime && log.salaryDeductionCode === 'early_checkout_quarter_day') {
         // 3. Handle early checkout forgiveness via permission
         const perm = approvedPermsByUserId[userId]?.['early_leave'];
         if (perm) {
           updates.salaryDeductionFraction = perm.salaryDeductionFraction || 0;
           updates.salaryDeductionAmount = perm.salaryDeductionAmount || 0;
           updates.salaryDeductionCode = perm.salaryDeductionCode || 'none';
           updates.salaryDeductionLabel = 'مغفور بإذن (انصراف مبكر)';
           updates.salaryDeductionApprovalStatus = (perm.salaryDeductionFraction || 0) > 0 ? 'pending_hr' : 'none';
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
