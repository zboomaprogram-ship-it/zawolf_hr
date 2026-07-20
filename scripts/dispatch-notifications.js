const admin = require('firebase-admin');
const { isOneSignalConfigured, sendPushToUsers } = require('./onesignal');
const {
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');
installFirestoreCompatibility(admin);

function dispatchConfig() {
  return {
    batchSize: Number(process.env.NOTIFICATION_DISPATCH_BATCH_SIZE || 50),
    perUserLimit: Number(process.env.NOTIFICATION_DISPATCH_PER_USER_LIMIT || 10),
    maxAttempts: Number(process.env.NOTIFICATION_DISPATCH_MAX_ATTEMPTS || 3),
  };
}

function isUnsubscribedDeviceError(error) {
  return String(error?.message || error || '')
    .toLowerCase()
    .includes('all included players are not subscribed');
}

function initializeFirebase() {
  const existingApp = getExistingFirebaseApp(admin);
  if (existingApp) return existingApp;

  const serviceAccount = parseFirebaseServiceAccount(
    process.env.FIREBASE_SERVICE_ACCOUNT,
  );

  const app = admin.initializeApp({
    credential: admin.cert(serviceAccount),
  });

  console.log(`Using Firebase service account: ${serviceAccount.client_email}`);
  console.log(`Firebase project id: ${serviceAccount.project_id}`);
  return app;
}

function routeForNotification(type) {
  const value = String(type || '');
  if (value === 'poll_created') return '/polls';
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
  const { batchSize, perUserLimit, maxAttempts } = dispatchConfig();
  // A collection-group query avoids scanning every user and then every user's
  // notification subcollection on each Hostinger interval.
  const candidatesSnap = await db.collectionGroup('items')
    .where('isRead', '==', false)
    .where('pushSent', '==', false)
    .limit(batchSize)
    .get();
  const userIds = [...new Set(candidatesSnap.docs.map((doc) => doc.ref.parent.parent?.id).filter(Boolean))];
  const userDocs = userIds.length
    ? await db.getAll(...userIds.map((userId) => db.collection('users').doc(userId)))
    : [];
  const activeUsers = new Set(
    userDocs.filter((doc) => doc.exists && doc.data()?.isActive === true).map((doc) => doc.id),
  );
  const pending = [];
  const perUserCount = new Map();

  for (const doc of candidatesSnap.docs) {
    if (pending.length >= batchSize) break;
    const userId = doc.ref.parent.parent?.id;
    if (!userId || !activeUsers.has(userId)) continue;
    if ((perUserCount.get(userId) || 0) >= perUserLimit) continue;
    const data = doc.data();
    const attempts = Number(data.pushAttemptCount || 0);
    const waitingForDeviceSubscription = isUnsubscribedDeviceError(
      data.pushLastError,
    );
    const nextRetryAt = data.pushNextRetryAt?.toDate?.();
    if (nextRetryAt && nextRetryAt > new Date()) continue;
    if (
      data.pushSent === true ||
      (attempts >= maxAttempts && !waitingForDeviceSubscription)
    ) {
      continue;
    }
    const claimed = await claimNotification(db, doc.ref);
    if (!claimed) continue;
    pending.push({ userId, ref: doc.ref, id: doc.id, data });
    perUserCount.set(userId, (perUserCount.get(userId) || 0) + 1);
  }

  return pending;
}

// Hostinger and the GitHub backup may overlap. Claim before OneSignal is called
// so the same unread record cannot produce two lock-screen notifications.
async function claimNotification(db, ref) {
  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    if (!doc.exists) return false;
    const data = doc.data();
    const currentClaim = data.pushClaimUntil?.toDate?.();
    if (data.pushSent === true || (currentClaim && currentClaim > new Date())) {
      return false;
    }
    transaction.update(ref, {
      pushClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
      pushClaimUntil: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 10 * 60 * 1000),
      ),
    });
    return true;
  });
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
      pushDeliveryStatus: 'sent',
      pushResponseId: result?.response?.id || null,
      pushLastError: admin.firestore.FieldValue.delete(),
      pushNextRetryAt: admin.firestore.FieldValue.delete(),
      pushClaimUntil: admin.firestore.FieldValue.delete(),
    });
    ops++;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
}

async function markWaitingForSubscription(db, items, error) {
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
      // An unsubscribed device cannot receive a retry. Close the push attempt
      // while preserving the Firestore item for the in-app notification list.
      // New notifications will work as soon as the user subscribes again.
      pushSent: true,
      pushDeliveryStatus: 'unsubscribed',
      pushFinishedAt: admin.firestore.FieldValue.serverTimestamp(),
      pushLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      pushLastError: String(error.message || error).slice(0, 500),
      pushNextRetryAt: admin.firestore.FieldValue.delete(),
      pushClaimUntil: admin.firestore.FieldValue.delete(),
    });
    ops++;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
}

async function markFailed(db, items, error) {
  const { maxAttempts } = dispatchConfig();
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
    const attempts = Number(item.data.pushAttemptCount || 0) + 1;
    const finalFailure = attempts >= maxAttempts;
    const retryDelayMinutes = Math.min(60, 5 * (2 ** Math.max(0, attempts - 1)));
    batch.update(item.ref, {
      pushAttemptCount: attempts,
      pushSent: finalFailure,
      pushDeliveryStatus: finalFailure ? 'failed' : 'retry_wait',
      pushLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      pushLastError: String(error.message || error).slice(0, 500),
      pushNextRetryAt: finalFailure
        ? admin.firestore.FieldValue.delete()
        : admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + retryDelayMinutes * 60 * 1000),
        ),
      ...(finalFailure
        ? { pushFinishedAt: admin.firestore.FieldValue.serverTimestamp() }
        : {}),
      pushClaimUntil: admin.firestore.FieldValue.delete(),
    });
    ops++;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
}

function watchPendingNotifications({ onPending, onError } = {}) {
  initializeFirebase();
  const db = admin.firestore();
  const { batchSize } = dispatchConfig();
  const query = db.collectionGroup('items')
    .where('isRead', '==', false)
    .where('pushSent', '==', false)
    .limit(batchSize);

  return query.onSnapshot(
    (snapshot) => {
      const added = snapshot.docChanges().filter((change) => change.type === 'added');
      if (added.length && typeof onPending === 'function') {
        onPending(added.length);
      }
    },
    (error) => {
      console.error('Pending notification listener failed:', error);
      if (typeof onError === 'function') onError(error);
    },
  );
}

async function dispatchNotifications() {
  initializeFirebase();

  if (!isOneSignalConfigured()) {
    throw new Error('ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY are required.');
  }

  const db = admin.firestore();
  const pending = await loadPendingNotifications(db);
  console.log(`Found ${pending.length} pending push notification(s).`);
  if (!pending.length) return { found: 0, sent: 0, failed: 0 };

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
      if (isUnsubscribedDeviceError(error)) {
        await markWaitingForSubscription(db, [item], error);
      } else {
        await markFailed(db, [item], error);
      }
      failed++;
      console.warn(
        `Failed to push notification ${item.id} to ${item.userId}: ${error.message}`,
      );
    }
  }

  console.log(`Notification dispatch complete. Sent: ${sent}. Failed: ${failed}.`);
  return { found: pending.length, sent, failed };
}

if (require.main === module) {
  dispatchNotifications()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Notification dispatch failed:', error);
      process.exit(1);
    });
}

module.exports = {
  dispatchNotifications,
  initializeFirebase,
  notificationPayload,
  routeForNotification,
  isUnsubscribedDeviceError,
  watchPendingNotifications,
};
