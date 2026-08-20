const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const {
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');

installFirestoreCompatibility(admin);

const rawEmails = String(process.env.ACCOUNT_EMAILS || '')
  .split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);
const apply = process.env.APPLY === 'true';
const resetDevices = process.env.RESET_ATTENDANCE_DEVICES === 'true';

if (rawEmails.length === 0) {
  throw new Error('ACCOUNT_EMAILS must contain one or more comma-separated email addresses.');
}
if (apply && !resetDevices) {
  throw new Error('Refusing to modify accounts without RESET_ATTENDANCE_DEVICES=true.');
}

const serviceAccount = parseFirebaseServiceAccount(
  process.env.FIREBASE_SERVICE_ACCOUNT || '',
);
admin.initializeApp({ credential: admin.cert(serviceAccount) });
const db = admin.firestore();
const auth = getAuth();

async function findUserDocument(email, authUid) {
  const byId = authUid ? await db.collection('users').doc(authUid).get() : null;
  if (byId?.exists) return byId;
  const matches = await db.collection('users').where('email', '==', email).limit(2).get();
  if (matches.size === 1) return matches.docs[0];
  if (matches.size > 1) {
    throw new Error(`${email}: more than one Firestore employee record matches this email.`);
  }
  return null;
}

async function inspectAndRepair(email) {
  let authUser;
  try {
    authUser = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log(`NOT_FOUND | ${email} | Firebase Authentication account does not exist`);
      return;
    }
    throw error;
  }

  const userDoc = await findUserDocument(email, authUser.uid);
  if (!userDoc) {
    console.log(`NOT_FOUND | ${email} | Firestore employee record does not exist`);
    return;
  }
  const user = userDoc.data() || {};
  const deviceDocs = await db
    .collection('attendanceDevices')
    .where('userId', '==', userDoc.id)
    .get();
  const registered = String(user.registeredAttendanceDeviceId || '');
  const report = {
    email,
    authUid: authUser.uid,
    firestoreUid: userDoc.id,
    authDisabled: authUser.disabled,
    isActive: user.isActive !== false,
    employeeId: String(user.employeeId || ''),
    role: String(user.role || ''),
    registeredAttendanceDeviceId: registered || '(none)',
    boundDeviceIds: deviceDocs.docs.map((doc) => doc.id),
  };
  console.log(`${apply ? 'REPAIRING' : 'CHECK'} | ${JSON.stringify(report)}`);

  if (!apply) return;

  // This deliberately changes only the account's attendance device identity.
  // It does not alter attendance, leave, payroll, location, or auth records.
  const batch = db.batch();
  for (const deviceDoc of deviceDocs.docs) batch.delete(deviceDoc.ref);
  batch.update(userDoc.ref, {
    registeredAttendanceDeviceId: admin.firestore.FieldValue.delete(),
    registeredAttendanceDeviceLabel: admin.firestore.FieldValue.delete(),
    registeredAttendanceDeviceAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`RESET | ${email} | device bindings cleared; next online attendance attempt will bind the current device.`);
}

async function main() {
  console.log(`Firebase project: ${serviceAccount.project_id}`);
  console.log(`Mode: ${apply ? 'APPLY device reset' : 'DRY RUN only'}`);
  for (const email of rawEmails) await inspectAndRepair(email);
}

main().catch((error) => {
  console.error(error.stack || error.message || error);
  process.exitCode = 1;
});
