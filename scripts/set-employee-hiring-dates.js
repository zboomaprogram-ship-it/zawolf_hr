const admin = require('firebase-admin');
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
const dryRun = process.env.DRY_RUN !== 'false';
const confirmation = process.env.MIGRATION_CONFIRMATION || '';
const requiredConfirmation = 'SET_ALL_HIRING_DATES_2026_01_01';
const hiringDate = admin.firestore.Timestamp.fromDate(
  new Date('2026-01-01T00:00:00+02:00'),
);
const eligibleFrom = admin.firestore.Timestamp.fromDate(
  new Date('2026-07-01T00:00:00+03:00'),
);

async function main() {
  if (!dryRun && confirmation !== requiredConfirmation) {
    throw new Error(
      `Live migration requires MIGRATION_CONFIRMATION=${requiredConfirmation}`,
    );
  }

  const users = await db.collection('users').get();
  console.log(`Firebase project: ${serviceAccount.project_id}`);
  console.log(`Users found: ${users.size}`);
  console.log(`Dry run: ${dryRun}`);

  let changed = 0;
  let batch = db.batch();
  let batchSize = 0;

  for (const doc of users.docs) {
    const data = doc.data();
    if (data.isActive === false && process.env.INCLUDE_INACTIVE !== 'true') {
      continue;
    }

    changed += 1;
    console.log(
      `${dryRun ? 'WOULD_UPDATE' : 'UPDATE'} | ` +
      `${data.employeeId || doc.id} | ${data.displayName || ''}`,
    );
    if (dryRun) continue;

    batch.update(doc.ref, {
      joinDate: hiringDate,
      leaveEligibleFrom: eligibleFrom,
      leaveEntitlementPeriodKey: '2026-07-01',
      leaveEntitlementQuota: 15,
      leaveEntitlementStatus: 'eligible',
      hiringDateMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batchSize += 1;

    if (batchSize === 400) {
      await batch.commit();
      batch = db.batch();
      batchSize = 0;
    }
  }

  if (!dryRun && batchSize > 0) await batch.commit();
  console.log(`${dryRun ? 'Previewed' : 'Updated'} ${changed} user(s).`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
