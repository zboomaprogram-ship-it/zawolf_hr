'use strict';

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
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();
const auth = getAuth();
const dryRun = String(process.env.DRY_RUN || 'true').toLowerCase() !== 'false';
const accountEmail = String(process.env.ACCOUNT_EMAIL || '').trim().toLowerCase();

function normalizedEmail(value) {
  return String(value || '').trim().toLowerCase();
}

async function listAuthUsers() {
  if (accountEmail) {
    try {
      return [await auth.getUserByEmail(accountEmail)];
    } catch (error) {
      if (error.code === 'auth/user-not-found') return [];
      throw error;
    }
  }

  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

async function updateDeviceBindings(batch, legacyId, canonicalUid) {
  const bindings = await db
    .collection('attendanceDevices')
    .where('userId', '==', legacyId)
    .get();

  for (const binding of bindings.docs) {
    batch.set(
      binding.ref,
      {
        userId: canonicalUid,
        identityRepairedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  return bindings.size;
}

async function main() {
  console.log(`Dry run: ${dryRun}`);
  if (accountEmail) console.log(`Account: ${accountEmail}`);

  const [authUsers, usersSnapshot] = await Promise.all([
    listAuthUsers(),
    db.collection('users').get(),
  ]);
  const docs = usersSnapshot.docs;
  let repaired = 0;
  let normalized = 0;
  let skipped = 0;

  for (const authUser of authUsers) {
    const canonical = docs.find((doc) => doc.id === authUser.uid);
    const email = normalizedEmail(authUser.email);
    const candidates = docs.filter((doc) => {
      if (doc.id === authUser.uid) return false;
      const data = doc.data();
      return (
        normalizedEmail(data.email) === email ||
        data.uid === authUser.uid ||
        data.canonicalUid === authUser.uid
      );
    });

    if (canonical) {
      const data = canonical.data();
      const needsNormalization =
          data.uid !== authUser.uid ||
          data.canonicalUid !== authUser.uid ||
          (email && normalizedEmail(data.email) !== email);
      if (!needsNormalization) continue;

      console.log(`NORMALIZE | ${email || authUser.uid} | ${canonical.id}`);
      if (!dryRun) {
        await canonical.ref.set(
          {
            uid: authUser.uid,
            canonicalUid: authUser.uid,
            ...(email ? { email } : {}),
            identityRepairedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      normalized += 1;
      continue;
    }

    if (candidates.length !== 1) {
      console.log(
        `SKIP | ${email || authUser.uid} | legacy matches=${candidates.length}`,
      );
      skipped += 1;
      continue;
    }

    const legacy = candidates[0];
    console.log(
      `REPAIR | ${email || authUser.uid} | ${legacy.id} -> ${authUser.uid}`,
    );
    if (!dryRun) {
      const batch = db.batch();
      batch.set(db.collection('users').doc(authUser.uid), {
        ...legacy.data(),
        uid: authUser.uid,
        canonicalUid: authUser.uid,
        ...(email ? { email } : {}),
        identityRepairedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.set(
        legacy.ref,
        {
          migratedToUid: authUser.uid,
          isLegacyIdentity: true,
          identityMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      const deviceCount = await updateDeviceBindings(
        batch,
        legacy.id,
        authUser.uid,
      );
      await batch.commit();
      console.log(`  Updated ${deviceCount} attendance device binding(s).`);
    }
    repaired += 1;
  }

  console.log(
    JSON.stringify({ dryRun, repaired, normalized, skipped }, null, 2),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
