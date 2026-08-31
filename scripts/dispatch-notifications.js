const admin = require('firebase-admin');
const { isOneSignalConfigured, sendPushToUsers } = require('./onesignal');
const {
  emulatorProjectId,
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');
const { loadCheckoutPolicy } = require('./checkout-policy');
const { requestStageNotification } = require('./company-os/notifications');
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

  const localProjectId = emulatorProjectId(process.env);
  if (localProjectId) {
    const app = admin.initializeApp({ projectId: localProjectId });
    console.log(`Using local Firebase emulators for project: ${localProjectId}`);
    return app;
  }

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
  if (value === 'hr_announcement') return '/notifications';
  if (value === 'account_deactivated') return '/account-disabled';
  if (value === 'warning_dismissal_review') return '/hr/employees';
  if (value === 'poll_created') return '/polls';
  if (value === 'attendance_security_review') return '/manager/requests';
  if (value === 'attendance_security_reviewed') return '/employee/dashboard';
  if (value === 'salary_deduction_pending') return '/manager/requests';
  if (value === 'salary_deduction_reviewed') return '/employee/deductions';
  if (value === 'complaint_new') return '/manager/requests';
  if (
    value === 'administrative_request_submitted' ||
    value === 'field_mission_pending_ceo'
  ) return '/manager/requests';
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
  if (value.includes('payroll') || value.includes('deduction')) {
    return '/employee/deductions';
  }
  if (value.includes('attendance')) return '/employee/dashboard';
  return '/notifications';
}

const SAFE_NOTIFICATION_ROUTES = new Set([
  '/notifications',
  '/account-disabled',
  '/polls',
  '/employee/dashboard',
  '/employee/requests',
  '/employee/deductions',
  '/employee/tasks',
  '/employee/warnings-rewards',
  '/employee/suggestions',
  '/employee/kpi',
  '/manager/requests',
  '/team-leader/requests',
  '/hr/requests',
  '/hr/employees',
]);

const NOTIFICATION_FOCUS_ID = /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/;
const HR_NOTIFICATION_ROLES = new Set(['hr_admin', 'hr_manager']);

function safeNotificationRoute(value) {
  const route = String(value || '').trim();
  if (SAFE_NOTIFICATION_ROUTES.has(route)) return route;
  return /^\/(?:employee\/requests|requests)\/operational\/[A-Za-z0-9_.:-]{1,128}$/.test(route)
    ? route
    : null;
}

function safeNotificationFocusId(value) {
  const focusId = String(value || '').trim();
  return NOTIFICATION_FOCUS_ID.test(focusId) ? focusId : null;
}

function normalizeNotificationResource(input) {
  const data = input?.data && typeof input.data === 'object' ? input.data : {};
  const type = String(input?.type || 'notification').trim().slice(0, 128);
  return {
    type: type || 'notification',
    focusId: safeNotificationFocusId(
      data.requestId || data.resourceId || data.targetId || data.attendanceId,
    ),
    storedRoute: safeNotificationRoute(data.route),
  };
}

function classifyRecipientRoute({ role, resource }) {
  const normalizedRole = String(role || 'employee');
  const type = String(resource?.type || 'notification').toLowerCase();
  let path;

  if (type.startsWith('company_os_request_') && resource?.storedRoute) {
    return {
      path: resource.storedRoute,
      focusId: safeNotificationFocusId(resource?.focusId),
      fallbackPath: resource.storedRoute,
    };
  }

  const employeeDecision = type.includes('approved') ||
    type.includes('rejected') || type.includes('reviewed');
  const managementRequest = type.includes('pending') ||
    type.includes('submitted') || type.endsWith('_new') ||
    type === 'attendance_security_review';

  if (employeeDecision) {
    path = routeForNotification(type);
    if (path === '/manager/requests' || path === '/hr/requests') {
      path = '/employee/requests';
    }
  } else if (managementRequest && HR_NOTIFICATION_ROLES.has(normalizedRole)) {
    path = '/hr/requests';
  } else if (managementRequest && normalizedRole === 'team_leader') {
    path = '/team-leader/requests';
  } else if (managementRequest &&
      (normalizedRole === 'manager' || normalizedRole === 'super_admin')) {
    path = '/manager/requests';
  } else {
    path = safeNotificationRoute(resource?.storedRoute) || routeForNotification(type);
  }

  path = safeNotificationRoute(path) || '/notifications';
  return {
    path,
    focusId: safeNotificationFocusId(resource?.focusId),
    fallbackPath: path,
  };
}

async function companyOsOutboxRecipients(db, outbox) {
  const directUid = String(outbox.recipientUid || '').trim();
  if (directUid) {
    const snapshot = await db.collection('users').doc(directUid).get();
    return snapshot.exists && snapshot.data()?.isActive === true ? [directUid] : [];
  }
  const role = String(outbox.recipientRole || '').trim();
  if (!role) return [];
  const snapshots = await Promise.all([
    db.collection('users').where('operationalRole', '==', role).limit(100).get(),
    db.collection('users').where('role', '==', role).limit(100).get(),
  ]);
  return [...new Set(snapshots.flatMap((snapshot) => snapshot.docs)
    .filter((doc) => doc.data()?.isActive === true)
    .map((doc) => doc.id))];
}

async function promoteCompanyOsNotificationOutbox(db) {
  const snapshot = await db.collection('companyOsNotificationOutbox')
    .where('dispatchStatus', '==', 'pending')
    .limit(Math.min(dispatchConfig().batchSize, 50))
    .get();
  let promoted = 0;
  for (const doc of snapshot.docs) {
    const outbox = doc.data();
    const recipients = await companyOsOutboxRecipients(db, outbox);
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(doc.ref);
      if (!current.exists || current.data()?.dispatchStatus !== 'pending') return;
      for (const recipientUid of recipients) {
        const notification = requestStageNotification({
          operationId: outbox.operationId || doc.id,
          requestId: outbox.requestId,
          recipientUid,
          stage: outbox.stage || 'manager',
          status: outbox.status || 'pending',
        });
        transaction.set(
          db.collection('notifications').doc(recipientUid).collection('items').doc(notification.id),
          {
            ...notification,
            isRead: false,
            pushSent: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        );
      }
      transaction.update(doc.ref, {
        dispatchStatus: recipients.length ? 'dispatched' : 'no_active_recipient',
        recipientCount: recipients.length,
        dispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    promoted += recipients.length;
  }
  return { outboxes: snapshot.size, promoted };
}

function notificationPayload(doc, data, recipientRole) {
  const rawData = data.data && typeof data.data === 'object' ? data.data : {};
  const destination = classifyRecipientRoute({
    role: recipientRole,
    resource: normalizeNotificationResource(data),
  });
  return {
    ...rawData,
    notificationId: doc.id,
    type: data.type || 'notification',
    requestId: destination.focusId,
    route: destination.path,
  };
}

const CHECK_IN_REMINDER_TYPES = new Set([
  'attendance_check_in_reminder',
  'attendance_late_warning',
  'attendance_final_warning',
]);

function reminderAction(data) {
  const type = String(data?.type || '');
  if (CHECK_IN_REMINDER_TYPES.has(type)) return 'check_in';
  if (type === 'attendance_check_out_reminder') return 'check_out';
  return null;
}

function isCheckoutReminderSuppressed(data, checkoutPolicy) {
  return reminderAction(data) === 'check_out' && checkoutPolicy?.enabled !== true;
}

function reminderDate(data) {
  const nested = data?.data && typeof data.data === 'object' ? data.data : {};
  const value = String(nested.date || '');
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

function attendanceCompletesReminder(attendanceData, action) {
  if (!attendanceData || !action) return false;
  if (action === 'check_in') return attendanceData.checkInTime != null;
  return attendanceData.checkOutTime != null;
}

async function loadAttendanceForReminder(db, userId, dateKey) {
  const deterministic = await db
    .collection('attendance')
    .doc(`${userId}_${dateKey}`)
    .get();
  if (deterministic.exists) return deterministic.data();

  const legacy = await db
    .collection('attendance')
    .where('userId', '==', userId)
    .where('date', '==', dateKey)
    .limit(1)
    .get();
  return legacy.empty ? null : legacy.docs[0].data();
}

async function shouldSkipAttendanceReminder(db, item, checkoutPolicy) {
  const action = reminderAction(item.data);
  const dateKey = reminderDate(item.data);
  if (!action || !dateKey) return false;
  if (isCheckoutReminderSuppressed(item.data, checkoutPolicy)) return true;
  const attendance = await loadAttendanceForReminder(
    db,
    item.userId,
    dateKey,
  );
  return attendanceCompletesReminder(attendance, action);
}

async function markSkipped(db, item, reason) {
  await item.ref.update({
    pushSent: true,
    isRead: true,
    pushDeliveryStatus: 'skipped',
    pushSkippedReason: reason,
    pushFinishedAt: admin.firestore.FieldValue.serverTimestamp(),
    pushClaimUntil: admin.firestore.FieldValue.delete(),
  });
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
  const userRoles = new Map(
    userDocs
      .filter((doc) => doc.exists)
      .map((doc) => [doc.id, String(doc.data()?.role || 'employee')]),
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
    pending.push({
      userId,
      recipientRole: userRoles.get(userId) || 'employee',
      ref: doc.ref,
      id: doc.id,
      data,
    });
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
  await promoteCompanyOsNotificationOutbox(db);
  const pending = await loadPendingNotifications(db);
  console.log(`Found ${pending.length} pending push notification(s).`);
  if (!pending.length) return { found: 0, sent: 0, failed: 0 };

  let sent = 0;
  let failed = 0;
  // Existing queued messages may predate the current policy. Resolve once and
  // revalidate them at delivery time before any OneSignal call.
  const checkoutPolicy = await loadCheckoutPolicy(db);

  for (const item of pending) {
    const title = item.data.title || 'تنبيه جديد';
    const body = item.data.body || '';
    const payload = notificationPayload(item, item.data, item.recipientRole);

    try {
      // Attendance may be recorded after a reminder was queued but before the
      // dispatcher reaches OneSignal. Revalidate at the final delivery edge.
      if (await shouldSkipAttendanceReminder(db, item, checkoutPolicy)) {
        const reason = reminderAction(item.data) === 'check_out' && !checkoutPolicy.enabled
          ? 'checkout_policy_disabled'
          : 'attendance_already_completed';
        await markSkipped(db, item, reason);
        console.log(
          `Skipped stale attendance reminder ${item.id} for ${item.userId}.`,
        );
        continue;
      }
      const result = await sendPushToUsers(
        [item.userId],
        title,
        body,
        payload,
        { idempotencyKey: `${item.userId}:${item.id}` },
      );
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
  safeNotificationRoute,
  normalizeNotificationResource,
  classifyRecipientRoute,
  isUnsubscribedDeviceError,
  reminderAction,
  isCheckoutReminderSuppressed,
  reminderDate,
  attendanceCompletesReminder,
  shouldSkipAttendanceReminder,
  watchPendingNotifications,
  companyOsOutboxRecipients,
  promoteCompanyOsNotificationOutbox,
};
