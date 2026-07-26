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
const dryRun = process.env.DRY_RUN !== 'false';
const confirmation = process.env.RESET_CONFIRMATION || '';
const requiredConfirmation = `RESET_ATTENDANCE_DEVICE:${email}`;

async function main() {
  if (!email) throw new Error('ACCOUNT_EMAIL is required.');
  if (!dryRun && confirmation !== requiredConfirmation) {
    throw new Error(
      `Live reset requires RESET_CONFIRMATION=${requiredConfirmation}`,
    );
  }

  const authUser = await getAuth().getUserByEmail(email);
  const userRef = db.collection('users').doc(authUser.uid);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) {
    throw new Error(`Firestore user ${authUser.uid} does not exist.`);
  }

  const user = userSnapshot.data();
  if (String(user.email || '').trim().toLowerCase() !== email) {
    throw new Error('Auth and Firestore email values do not match.');
  }

  const bindings = await db
    .collection('attendanceDevices')
    .where('userId', '==', authUser.uid)
    .get();
  const registeredDeviceId = String(
    user.registeredAttendanceDeviceId || '',
  ).trim();

  console.log(`Firebase project: ${serviceAccount.project_id}`);
  console.log(`Account: ${email}`);
  console.log(`UID: ${authUser.uid}`);
  console.log(`Dry run: ${dryRun}`);
  console.log(`Registered device: ${registeredDeviceId || 'none'}`);
  console.log(
    `Owned bindings: ${bindings.docs.map((doc) => doc.id).join(',') || 'none'}`,
  );

  if (dryRun) {
    console.log('WOULD_RESET attendance device binding.');
    return;
  }

  const batch = db.batch();
  for (const binding of bindings.docs) {
    if (binding.data().userId !== authUser.uid) {
      throw new Error(`Refusing to delete unowned binding ${binding.id}.`);
    }
    batch.delete(binding.ref);
  }
  batch.update(userRef, {
    registeredAttendanceDeviceId: admin.firestore.FieldValue.delete(),
    registeredAttendanceDeviceLabel: admin.firestore.FieldValue.delete(),
    registeredAttendanceDeviceAt: admin.firestore.FieldValue.delete(),
  });
  await batch.commit();

  console.log('RESET_COMPLETE attendance device binding cleared.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
