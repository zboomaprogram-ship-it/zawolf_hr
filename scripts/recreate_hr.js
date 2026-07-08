const admin = require('firebase-admin');
const serviceAccount = require('/Users/seg/Downloads/zawolf-hr-system-60317-firebase-adminsdk-fbsvc-92ac87dc9b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createHRUser() {
  const email = 'hr@zawolf.com';
  const password = 'ZW@admin';
  const displayName = 'HR Admin - Zawolf';

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
      employeeId: 'HR-201',
      department: 'Human Resources',
      position: 'HR Manager',
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
        annual: 21,
        sick: 14,
        casual: 7,
        daysOff: 21
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
