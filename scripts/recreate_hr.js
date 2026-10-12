const admin = require('firebase-admin');
const {
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');
installFirestoreCompatibility(admin);
const serviceAccount = parseFirebaseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT);

const email = String(process.env.HR_BOOTSTRAP_EMAIL || '').trim();
const password = String(process.env.HR_BOOTSTRAP_PASSWORD || '');
const displayName = String(process.env.HR_BOOTSTRAP_DISPLAY_NAME || 'HR Admin').trim();
const employeeId = String(process.env.HR_BOOTSTRAP_EMPLOYEE_ID || '').trim();
if (!email || password.length < 12 || !employeeId) {
  throw new Error(
    'Set HR_BOOTSTRAP_EMAIL, HR_BOOTSTRAP_PASSWORD (12+ characters), and HR_BOOTSTRAP_EMPLOYEE_ID.',
  );
}

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const db = admin.firestore();

async function createHRUser() {
  try {
    console.log(`Creating user in Auth: ${email}...`);
    // Attempt to delete it first just in case it exists in auth but not firestore
    try {
      const existingUser = await admin.auth().getUserByEmail(email);
      await admin.auth().deleteUser(existingUser.uid);
      console.log('Deleted existing auth user to recreate cleanly.');
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }

    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
      emailVerified: true
    });
    
    console.log(`Successfully created new user: ${userRecord.uid}`);
    
    const uid = userRecord.uid;
    const userData = {
      uid: uid,
      email: email,
      displayName: displayName,
      role: 'hr_admin',
      employeeId,
      department: 'Human Resources',
      position: 'HR',
      locationId: 'Zawolf',
      locationName: 'Zawolf',
      baseMonthlySalary: 0,
      salaryCurrency: 'EGP',
      isActive: true,
      joinDate: admin.firestore.FieldValue.serverTimestamp(),
      managerId: '',
      managerName: '',
      workSchedule: {
        startTime: "09:00",
        endTime: "17:00",
        workDays: [1, 2, 3, 4, 0]
      },
      leaveBalance: {
        annual: 15,
        sick: 14,
        casual: 7,
        daysOff: 15
      },
      permissionBalance: {
        usedThisMonth: 0,
        usedHoursThisMonth: 0.0,
        lastResetMonth: ""
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('users').doc(uid).set(userData);
    console.log('Successfully created user document in Firestore.');
    
  } catch (error) {
    console.error('Error creating new user:', error);
  } finally {
    process.exit(0);
  }
}

createHRUser();
