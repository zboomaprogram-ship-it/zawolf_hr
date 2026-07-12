const admin = require('firebase-admin');

const ROLES = ['hr_admin', 'manager', 'super_admin'];

function initializeFirebase() {
  if (admin.apps.length) return;

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (_) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is missing or invalid JSON.');
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log(`Using Firebase service account: ${serviceAccount.client_email}`);
  console.log(`Firebase project id: ${serviceAccount.project_id}`);
}

async function main() {
  initializeFirebase();
  const db = admin.firestore();

  for (const role of ROLES) {
    const snap = await db
      .collection('users')
      .where('role', '==', role)
      .where('isActive', '==', true)
      .get();

    const userIds = snap.docs.map((doc) => doc.id).sort();
    await db.collection('notificationRecipients').doc(role).set({
      role,
      userIds,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`SYNCED ${role}: ${userIds.length} active users`);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
