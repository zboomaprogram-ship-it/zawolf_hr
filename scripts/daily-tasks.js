const admin = require('firebase-admin');

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

async function runDailyTasks() {
  console.log('Starting daily tasks...');
  
  // Get date in Egypt time (GMT+3)
  const options = { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' };
  const formatter = new Intl.DateTimeFormat('en-CA', options); // en-CA gives YYYY-MM-DD
  
  // Create a Date object offset to Cairo time for getting the correct weekday
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
  const leavesSnap = await db.collection('leaves').where('status', '==', 'approved').get();
  const activeLeavesByUserId = {};
  leavesSnap.docs.forEach(doc => {
    const leave = doc.data();
    if (leave.startDate <= todayStr && leave.endDate >= todayStr) {
      activeLeavesByUserId[leave.userId] = leave;
    }
  });

  // Fetch all active employees
  const usersSnap = await db.collection('users').where('isActive', '==', true).get();
  console.log(`Found ${usersSnap.size} active users.`);

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
  let checkoutsClosed = 0;

  const batch = db.batch();

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
        // They didn't check in, but it's their day off. Skip completely!
        continue;
      }

      // User did not check in. Are they on leave?
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
        absentsCreated++;

        // Notify HR
        const notifRef = db.collection('notifications').doc(userId).collection('items').doc();
        batch.set(notifRef, {
          notificationId: notifRef.id,
          type: 'salary_deduction_pending',
          title: 'غياب بانتظار مراجعة HR',
          body: `${user.displayName}: غياب عن يوم ${todayStr} (${amount.toFixed(2)} ${user.salaryCurrency || 'EGP'}).`,
          data: { attendanceId: attendanceId },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batch.update(userDoc.ref, {
          unreadNotifications: admin.firestore.FieldValue.increment(1)
        });
      }
    } else {
      const log = attendanceSnap.data();
      
      // Check if they forgot to checkout
      if (log.checkInTime && !log.checkOutTime) {
        if (log.salaryDeductionFraction < 0.25) {
          const salaryDeductionFraction = 0.25;
          const baseSalary = user.baseMonthlySalary || 0;
          const amount = (baseSalary / payrollWorkDaysPerMonth) * salaryDeductionFraction;

          batch.update(attendanceRef, {
            checkOutTime: admin.firestore.FieldValue.serverTimestamp(),
            checkOutLocation: log.checkInLocation,
            localCheckOutTime: admin.firestore.FieldValue.serverTimestamp(),
            totalWorkHours: 0,
            checkOutDeviceId: log.deviceId || 'system_auto_close',
            checkOutDeviceLabel: 'System Auto Close',
            checkOutBiometricVerified: true,
            salaryDeductionFraction: salaryDeductionFraction,
            salaryDeductionAmount: amount,
            salaryDeductionCode: 'missed_checkout_quarter_day',
            salaryDeductionLabel: 'خصم ربع يوم - عدم تسجيل الانصراف',
            salaryDeductionApprovalStatus: 'pending_hr',
            salaryDeductionDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          checkoutsClosed++;

          // Notify HR
          const notifRef = db.collection('notifications').doc(userId).collection('items').doc();
          batch.set(notifRef, {
            notificationId: notifRef.id,
            type: 'salary_deduction_pending',
            title: 'خصم عدم تسجيل انصراف بانتظار مراجعة HR',
            body: `${user.displayName}: خصم ربع يوم - عدم تسجيل الانصراف عن يوم ${todayStr} (${amount.toFixed(2)} ${user.salaryCurrency || 'EGP'}).`,
            data: { attendanceId: attendanceId },
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          batch.update(userDoc.ref, {
            unreadNotifications: admin.firestore.FieldValue.increment(1)
          });
        } else {
          // They already have a deduction (e.g., late half day), just close the shift without extra deduction
          batch.update(attendanceRef, {
            checkOutTime: admin.firestore.FieldValue.serverTimestamp(),
            checkOutLocation: log.checkInLocation,
            localCheckOutTime: admin.firestore.FieldValue.serverTimestamp(),
            totalWorkHours: 0,
            checkOutDeviceId: log.deviceId || 'system_auto_close',
            checkOutDeviceLabel: 'System Auto Close',
            checkOutBiometricVerified: true,
          });
          checkoutsClosed++;
        }
      }
    }
  }

  if (absentsCreated > 0 || leavesCreated > 0 || checkoutsClosed > 0) {
    await batch.commit();
    console.log(`Successfully committed! Created ${absentsCreated} absences, ${leavesCreated} leaves, and auto-closed ${checkoutsClosed} shifts.`);
  } else {
    console.log('No action required. All employees checked in and out properly.');
  }
}

runDailyTasks()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Error running daily tasks:', error);
    process.exit(1);
  });
