const admin = require('firebase-admin');
const {
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');

installFirestoreCompatibility(admin);

function initialize() {
  if (getExistingFirebaseApp(admin)) return;
  const serviceAccount = parseFirebaseServiceAccount(
    process.env.FIREBASE_SERVICE_ACCOUNT,
  );
  admin.initializeApp({ credential: admin.cert(serviceAccount) });
}

async function migrateHrManagerRole({ dryRun = true } = {}) {
  initialize();
  const db = admin.firestore();
  const snapshot = await db
    .collection('users')
    .where('role', '==', 'hr_manager')
    .get();
  if (dryRun || snapshot.empty) {
    return {
      dryRun,
      found: snapshot.size,
      updated: 0,
      users: snapshot.docs.map((doc) => ({
        uid: doc.id,
        employeeId: doc.data().employeeId || '',
        displayName: doc.data().displayName || '',
      })),
    };
  }
  let updated = 0;
  for (let index = 0; index < snapshot.docs.length; index += 400) {
    const batch = db.batch();
    const docs = snapshot.docs.slice(index, index + 400);
    docs.forEach((doc) => batch.update(doc.ref, {
      role: 'hr_admin',
      previousRole: 'hr_manager',
      roleMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
    await batch.commit();
    updated += docs.length;
  }
  const hrSnapshot = await db
    .collection('users')
    .where('role', '==', 'hr_admin')
    .where('isActive', '==', true)
    .get();
  const activeHrIds = hrSnapshot.docs.map((doc) => doc.id).sort();
  await Promise.all([
    db.collection('notificationRecipients').doc('hr_admin').set({
      role: 'hr_admin',
      userIds: activeHrIds,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('notificationRecipients').doc('hr_manager').set({
      role: 'hr_manager',
      userIds: [],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  ]);
  return { dryRun, found: snapshot.size, updated };
}

if (require.main === module) {
  migrateHrManagerRole({ dryRun: process.env.DRY_RUN !== 'false' })
    .then((result) => console.log(JSON.stringify(result, null, 2)))
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
}

module.exports = { migrateHrManagerRole };
