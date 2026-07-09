const admin = require('firebase-admin');
const { isOneSignalConfigured, sendPushToUsers } = require('./onesignal');

const batchSize = Number(process.env.NOTIFICATION_DISPATCH_BATCH_SIZE || 100);
const perUserLimit = Number(process.env.NOTIFICATION_DISPATCH_PER_USER_LIMIT || 20);
const maxAttempts = Number(process.env.NOTIFICATION_DISPATCH_MAX_ATTEMPTS || 5);

function initializeFirebase() {
  let serviceAccount;
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (_) {
    console.error('FIREBASE_SERVICE_ACCOUNT is missing or invalid JSON.');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log(`Using Firebase service account: ${serviceAccount.client_email}`);
  console.log(`Firebase project id: ${serviceAccount.project_id}`);
}

function routeForNotification(type) {
  const value = String(type || '');
  if (value === 'attendance_security_review') return '/manager/requests';
  if (value === 'attendance_security_reviewed') return '/employee/dashboard';
  if (value === 'salary_deduction_pending') return '/manager/requests';
  if (value === 'salary_deduction_reviewed') return '/employee/dashboard';
  if (value === 'complaint_new') return '/manager/requests';
  if (value.includes('pending_hr') || value.includes('pending_manager')) {
    return '/manager/requests';
  }
  if (
    value.includes('approved') ||
    value.includes('rejected') ||
    value.includes('permission') ||
    value.includes('leave') ||
    value.includes('advance')
  ) {
    return '/employee/requests';
  }
  if (value.includes('task')) return '/employee/tasks';
  if (value.includes('warning') || value.includes('reward')) {
    return '/employee/warnings-rewards';
  }
  if (value.includes('suggestion')) return '/employee/suggestions';
  if (value.includes('kpi') || value.includes('performance')) {
    return '/employee/kpi';
  }
  if (value.includes('attendance')) return '/employee/dashboard';
  return '/employee/dashboard';
}

function notificationPayload(doc, data) {
  const rawData = data.data && typeof data.data === 'object' ? data.data : {};
  return {
    ...rawData,
    notificationId: doc.id,
    type: data.type || 'notification',
    route: rawData.route || routeForNotification(data.type),
  };
}

async function loadPendingNotifications(db) {
  const usersSnap = await db.collection('users').where('isActive', '==', true).get();
  const pending = [];

  for (const userDoc of usersSnap.docs) {
    if (pending.length >= batchSize) break;
    const userId = userDoc.id;
    const snap = await db
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .where('isRead', '==', false)
      .limit(perUserLimit)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      const attempts = Number(data.pushAttemptCount || 0);
      if (data.pushSent === true || attempts >= maxAttempts) continue;
      pending.push({ userId, ref: doc.ref, id: doc.id, data });
      if (pending.length >= batchSize) break;
    }
  }

  return pending;
}

async function markSent(db, items, result) {
  let batch = db.batch();
  let ops = 0;

  async function commitIfNeeded(force = false) {
    if (ops >= 450 || (force && ops > 0)) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  for (const item of items) {
    batch.update(item.ref, {
      pushSent: true,
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushProvider: 'onesignal',
      pushResponseId: result?.response?.id || null,
      pushLastError: admin.firestore.FieldValue.delete(),
    });
    ops++;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
}

async function markFailed(db, items, error) {
  let batch = db.batch();
  let ops = 0;

  async function commitIfNeeded(force = false) {
    if (ops >= 450 || (force && ops > 0)) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  for (const item of items) {
    batch.update(item.ref, {
      pushAttemptCount: admin.firestore.FieldValue.increment(1),
      pushLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      pushLastError: String(error.message || error).slice(0, 500),
    });
    ops++;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
}

async function dispatchNotifications() {
  initializeFirebase();

  if (!isOneSignalConfigured()) {
    console.error('ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY are required.');
    process.exit(1);
  }

  const db = admin.firestore();
  const pending = await loadPendingNotifications(db);
  console.log(`Found ${pending.length} pending push notification(s).`);
  if (!pending.length) return;

  let sent = 0;
  let failed = 0;

  for (const item of pending) {
    const title = item.data.title || 'تنبيه جديد';
    const body = item.data.body || '';
    const payload = notificationPayload(item, item.data);

    try {
      const result = await sendPushToUsers([item.userId], title, body, payload);
      if (result.sent) {
        await markSent(db, [item], result);
        sent++;
      } else {
        await markFailed(db, [item], new Error(result.reason || 'Push was not sent.'));
        failed++;
      }
    } catch (error) {
      await markFailed(db, [item], error);
      failed++;
      console.warn(
        `Failed to push notification ${item.id} to ${item.userId}: ${error.message}`,
      );
    }
  }

  console.log(`Notification dispatch complete. Sent: ${sent}. Failed: ${failed}.`);
}

dispatchNotifications()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Notification dispatch failed:', error);
    process.exit(1);
  });
