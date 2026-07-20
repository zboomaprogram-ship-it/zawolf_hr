const admin = require('firebase-admin');
const {
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');

installFirestoreCompatibility(admin);

const serviceAccount = parseFirebaseServiceAccount(
  process.env.FIREBASE_SERVICE_ACCOUNT || '',
);
const dryRun = process.env.DRY_RUN !== 'false';
const confirmation = process.env.MIGRATION_CONFIRMATION || '';
const requiredConfirmation = 'MIGRATE_MANAGER_FIRST_REQUESTS';

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

const db = admin.firestore();

function orderedManagerIds(data) {
  const rawIds = Array.isArray(data.managerIds) ? data.managerIds : [];
  const fallback = typeof data.managerId === 'string' ? data.managerId : '';
  const values = rawIds.length > 0 ? rawIds : [fallback];
  return [...new Set(values.map((value) => String(value).trim()).filter(Boolean))];
}

async function loadPendingHrRequests(collectionName) {
  const snapshot = await db
    .collection(collectionName)
    .where('status', '==', 'pending_hr')
    .get();

  return snapshot.docs.map((doc) => ({
    collectionName,
    doc,
    data: doc.data(),
  }));
}

async function main() {
  if (!dryRun && confirmation !== requiredConfirmation) {
    throw new Error(
      `Live migration requires MIGRATION_CONFIRMATION=${requiredConfirmation}`,
    );
  }

  console.log(`Using Firebase project: ${serviceAccount.project_id}`);
  console.log(`Dry run: ${dryRun}`);

  const requests = (
    await Promise.all([
      loadPendingHrRequests('permissions'),
      loadPendingHrRequests('leaves'),
    ])
  ).flat();

  const migratable = [];
  const skipped = [];
  for (const request of requests) {
    const managerIds = orderedManagerIds(request.data);
    if (managerIds.length === 0) {
      skipped.push(request);
      continue;
    }
    migratable.push({...request, managerIds});
  }

  console.log(`Pending HR requests found: ${requests.length}`);
  console.log(`Requests ready for manager-first migration: ${migratable.length}`);
  console.log(`Requests skipped because no manager is assigned: ${skipped.length}`);
  for (const request of skipped) {
    console.log(`SKIP_NO_MANAGER | ${request.collectionName}/${request.doc.id}`);
  }

  if (dryRun) {
    for (const request of migratable) {
      console.log(
        `WOULD_MIGRATE | ${request.collectionName}/${request.doc.id} | firstManager=${request.managerIds[0]}`,
      );
    }
    return;
  }

  let batch = db.batch();
  let operationCount = 0;
  let committedCount = 0;

  async function commit(force = false) {
    if (operationCount === 0 || (!force && operationCount < 350)) return;
    await batch.commit();
    committedCount += operationCount;
    operationCount = 0;
    batch = db.batch();
  }

  for (const request of migratable) {
    const managerId = request.managerIds[0];
    batch.update(request.doc.ref, {
      status: 'pending_manager',
      managerId,
      managerIds: request.managerIds,
      managerApprovalIndex: 0,
      managerApprovalTotal: request.managerIds.length,
      managerApprovalTrail: Array.isArray(request.data.managerApprovalTrail)
        ? request.data.managerApprovalTrail
        : [],
      migratedToManagerFirstAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    operationCount++;

    const notificationRef = db
      .collection('users')
      .doc(managerId)
      .collection('notifications')
      .doc();
    const isPermission = request.collectionName === 'permissions';
    batch.set(notificationRef, {
      notificationId: notificationRef.id,
      type: isPermission
        ? 'permission_pending_manager'
        : 'leave_request_submitted',
      title: isPermission
        ? 'طلب إذن بانتظار موافقتك'
        : 'طلب إجازة بانتظار موافقتك',
      body: `${request.data.employeeName || 'موظف'} لديه طلب بانتظار قرارك.`,
      data: isPermission
        ? {permissionId: request.doc.id}
        : {leaveId: request.doc.id},
      isRead: false,
      pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    operationCount++;
    await commit();
  }
  await commit(true);

  console.log(`Migration complete. Firestore operations committed: ${committedCount}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
