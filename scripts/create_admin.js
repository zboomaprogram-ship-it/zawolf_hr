const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

function currentCairoMonthKey() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date());
  const year = parts.find(part => part.type === 'year').value;
  const month = parts.find(part => part.type === 'month').value;
  return `${year}-${month}`;
}

// Initialize the app
initializeApp({
  projectId: "zawolf-hr-system-60317",
  credential: applicationDefault() 
});

async function createHRAdmin() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  const employeeId = process.env.ADMIN_EMPLOYEE_ID || "0001";
  const displayName = process.env.ADMIN_DISPLAY_NAME || "HR Admin";
  const role = process.env.ADMIN_ROLE || "hr_admin";

  if (!email || !password) {
    throw new Error(
      "Set ADMIN_EMAIL and ADMIN_PASSWORD before running this script.",
    );
  }

  try {
    const userRecord = await getAuth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    console.log("Successfully created new user:", userRecord.uid);

    // Create firestore document
    const db = getFirestore();
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: email,
      displayName: displayName,
      role: role,
      employeeId: employeeId,
      department: "HR",
      position: "HR Admin",
      locationId: "HQ",
      locationName: "Headquarters",
      baseMonthlySalary: Number(process.env.ADMIN_MONTHLY_SALARY || 0),
      salaryCurrency: process.env.ADMIN_SALARY_CURRENCY || "EGP",
      managerId: null,
      managerName: null,
      isActive: true,
      joinDate: FieldValue.serverTimestamp(),
      leaveBalance: {
        annual: 15,
        sick: 14,
        casual: 7,
        daysOff: 15
      },
      permissionBalance: {
        usedThisMonth: 0,
        usedHoursThisMonth: 0,
        lastResetMonth: currentCairoMonthKey()
      },
      workSchedule: {
        startTime: "09:00",
        endTime: "17:00",
        workDays: [6, 7, 1, 2, 3, 4]
      },
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });

    console.log("Successfully created user document in Firestore.");
  } catch (error) {
    console.error("Error creating new user:", error);
  }
}

createHRAdmin();
