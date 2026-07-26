const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const {
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');

installFirestoreCompatibility(admin);

const serviceAccount = parseFirebaseServiceAccount(
  process.env.FIREBASE_SERVICE_ACCOUNT || '',
);
admin.initializeApp({ credential: admin.cert(serviceAccount) });

const db = admin.firestore();
const email = (process.env.ACCOUNT_EMAIL || '').trim().toLowerCase();

function safeUser(data) {
  return {
    email: data.email || '',
    employeeId: data.employeeId || '',
    displayName: data.displayName || '',
    role: data.role || '',
    isActive: data.isActive !== false,
    locationId: data.locationId || '',
    locationName: data.locationName || '',
    registeredAttendanceDeviceId: data.registeredAttendanceDeviceId || '',
    registeredAttendanceDeviceLabel:
      data.registeredAttendanceDeviceLabel || '',
  };
}

async function main() {
  if (!email) throw new Error('ACCOUNT_EMAIL is required.');

  let authUser = null;
  try {
    authUser = await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }

  const emailMatches = await db
    .collection('users')
    .where('email', '==', email)
    .get();
  const employeeMatches = await db
    .collection('users')
    .where('employeeId', '==', 'MKT-604')
    .get();
  const docs = new Map();
  for (const doc of [...emailMatches.docs, ...employeeMatches.docs]) {
    docs.set(doc.id, doc);
  }

  console.log(`Firebase project: ${serviceAccount.project_id}`);
  console.log(`Requested email: ${email}`);
  console.log(
    `Auth user: ${authUser ? `${authUser.uid} | disabled=${authUser.disabled}` : 'NOT_FOUND'}`,
  );
  console.log(`Matching Firestore user documents: ${docs.size}`);

  for (const [id, doc] of docs) {
    const data = doc.data();
    console.log(`USER | ${id} | ${JSON.stringify(safeUser(data))}`);

    const registeredId = data.registeredAttendanceDeviceId || '';
    if (registeredId) {
      const binding = await db
        .collection('attendanceDevices')
        .doc(registeredId)
        .get();
      console.log(
        `REGISTERED_DEVICE | exists=${binding.exists} | owner=${binding.data()?.userId || ''}`,
      );
    }

    const bindings = await db
      .collection('attendanceDevices')
      .where('userId', '==', id)
      .get();
    console.log(
      `OWNED_DEVICE_BINDINGS | count=${bindings.size} | ids=${bindings.docs.map((item) => item.id).join(',')}`,
    );

    const attendance = await db
      .collection('attendance')
      .where('userId', '==', id)
      .orderBy('date', 'desc')
      .limit(3)
      .get();
    for (const item of attendance.docs) {
      const value = item.data();
      console.log(
        `ATTENDANCE | ${item.id} | date=${value.date || ''} | deviceId=${value.deviceId || ''} | protocol=${value.securityProtocolVersion ?? 'missing'}`,
      );
    }
  }

  const security = await db.doc('publicConfig/appSecurity').get();
  const company = await db.doc('settings/company').get();
  console.log(
    `SECURITY_POLICY | minimumAttendanceProtocolVersion=${security.data()?.minimumAttendanceProtocolVersion ?? 0}`,
  );
  console.log(
    `ATTENDANCE_MODE | ${company.data()?.attendancePolicy?.attendanceVerificationMode || 'location_only'}`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
