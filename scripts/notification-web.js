const http = require('http');
const { URL } = require('url');
const {
  dispatchNotifications,
  watchPendingNotifications,
} = require('./dispatch-notifications');
const { queueAttendanceReminders } = require('./attendance-reminders');
const { processAutomaticAttendance } = require('./auto-attendance');

const port = Number(process.env.PORT || 3000);
const dispatchSecret = process.env.NOTIFICATION_DISPATCH_SECRET || '';
const backgroundIntervalMs = Math.max(
  5 * 60 * 1000,
  Number(process.env.NOTIFICATION_DISPATCH_INTERVAL_MS || 5 * 60 * 1000),
);
const quotaBackoffMs = Math.max(
  15 * 60 * 1000,
  Number(process.env.FIRESTORE_QUOTA_BACKOFF_MS || 60 * 60 * 1000),
);
const pushFallbackIntervalMs = Math.max(
  30 * 60 * 1000,
  Number(process.env.NOTIFICATION_FALLBACK_INTERVAL_MS || 60 * 60 * 1000),
);
let runningDispatch = null;
let firestoreQuotaBlockedUntil = 0;
let pendingDispatchTimer = null;
let notificationUnsubscribe = null;
const diagnostics = {
  lastPushAt: null,
  lastPushResult: null,
  lastReminderAt: null,
  lastReminderResult: null,
  listenerError: null,
};

function isFirestoreQuotaError(error) {
  const message = String(error?.message || error || '');
  return error?.code === 8 || message.includes('RESOURCE_EXHAUSTED') || message.includes('Quota exceeded');
}

function pauseForFirestoreQuota(error) {
  firestoreQuotaBlockedUntil = Date.now() + quotaBackoffMs;
  console.warn(
    `Firestore quota is exhausted. Background notification work is paused for ${Math.round(quotaBackoffMs / 60000)} minutes: ${String(error?.message || error)}`,
  );
}

function schedulePushDispatch(reason = 'firestore_trigger', delayMs = 750) {
  if (Date.now() < firestoreQuotaBlockedUntil) return;
  if (pendingDispatchTimer) clearTimeout(pendingDispatchTimer);
  pendingDispatchTimer = setTimeout(() => {
    pendingDispatchTimer = null;
    void runTriggeredPush(reason);
  }, delayMs);
}

async function runTriggeredPush(reason) {
  if (Date.now() < firestoreQuotaBlockedUntil) return;
  if (runningDispatch) {
    schedulePushDispatch(reason, 2000);
    return;
  }
  runningDispatch = dispatchNotifications();
  try {
    const result = await runningDispatch;
    diagnostics.lastPushAt = new Date().toISOString();
    diagnostics.lastPushResult = result;
    if (result.found || result.failed) {
      console.log(`Triggered push dispatch (${reason}):`, result);
    }
    // Drain a backlog in bounded batches without returning to five-minute
    // scans. One final empty pass confirms that the queue is clear.
    if (result.found > 0) schedulePushDispatch('queue_drain', 1000);
  } catch (error) {
    if (isFirestoreQuotaError(error)) pauseForFirestoreQuota(error);
    console.error(`Triggered push dispatch failed (${reason}):`, error);
    diagnostics.lastPushAt = new Date().toISOString();
    diagnostics.lastPushResult = { error: String(error.message || error) };
  } finally {
    runningDispatch = null;
  }
}

function startNotificationListener() {
  if (notificationUnsubscribe) notificationUnsubscribe();
  try {
    notificationUnsubscribe = watchPendingNotifications({
      onPending: (count) => {
        diagnostics.listenerError = null;
        console.log(`Firestore notification trigger received ${count} new item(s).`);
        schedulePushDispatch('firestore_trigger');
      },
      onError: (error) => {
        const quotaError = isFirestoreQuotaError(error);
        if (quotaError) pauseForFirestoreQuota(error);
        diagnostics.listenerError = String(error.message || error);
        notificationUnsubscribe = null;
        setTimeout(
          startNotificationListener,
          quotaError ? quotaBackoffMs : 60 * 1000,
        );
      },
    });
  } catch (error) {
    diagnostics.listenerError = String(error.message || error);
    console.error('Could not start pending notification listener:', error);
    notificationUnsubscribe = null;
    setTimeout(startNotificationListener, 60 * 1000);
  }
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(body);
}

function isAuthorized(req, url) {
  if (!dispatchSecret) return false;
  const auth = req.headers.authorization || '';
  const bearer = auth.startsWith('Bearer ') ? auth.slice('Bearer '.length) : '';
  return (
    bearer === dispatchSecret ||
    req.headers['x-notification-dispatch-secret'] === dispatchSecret
  );
}

async function handleDispatch(req, res, url) {
  if (!isAuthorized(req, url)) {
    sendJson(res, 401, { ok: false, error: 'Unauthorized' });
    return;
  }

  if (runningDispatch) {
    sendJson(res, 202, {
      ok: true,
      status: 'already_running',
      message: 'A notification dispatch is already in progress.',
    });
    return;
  }

  const startedAt = new Date().toISOString();
  runningDispatch = (async () => {
    const automaticAttendance = await processAutomaticAttendance();
    const push = await dispatchNotifications();
    return { automaticAttendance, ...push };
  })();
  try {
    const result = await runningDispatch;
    diagnostics.lastPushAt = new Date().toISOString();
    diagnostics.lastPushResult = result;
    sendJson(res, 200, {
      ok: true,
      startedAt,
      finishedAt: new Date().toISOString(),
      ...result,
    });
  } catch (error) {
    console.error('Hostinger notification dispatch failed:', error);
    sendJson(res, 500, {
      ok: false,
      startedAt,
      finishedAt: new Date().toISOString(),
      error: String(error.message || error),
    });
  } finally {
    runningDispatch = null;
  }
}

async function handleAttendanceReminders(req, res, url) {
  if (!isAuthorized(req, url)) {
    sendJson(res, 401, { ok: false, error: 'Unauthorized' });
    return;
  }
  if (runningDispatch) {
    sendJson(res, 202, { ok: true, status: 'already_running' });
    return;
  }
  runningDispatch = (async () => {
    const automaticAttendance = await processAutomaticAttendance();
    const reminders = await queueAttendanceReminders();
    const push = await dispatchNotifications();
    return { automaticAttendance, reminders, push };
  })();
  try {
    const result = await runningDispatch;
    diagnostics.lastReminderAt = new Date().toISOString();
    diagnostics.lastReminderResult = result.reminders;
    diagnostics.lastPushAt = new Date().toISOString();
    diagnostics.lastPushResult = result.push;
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    console.error('Attendance reminder dispatch failed:', error);
    sendJson(res, 500, { ok: false, error: String(error.message || error) });
  } finally {
    runningDispatch = null;
  }
}

// Hostinger keeps this Node process alive, so it can deliver pushes without
// depending on GitHub's best-effort scheduled workflow. Firestore's claim and
// reminder-run documents make this safe when a manual endpoint or GitHub run
// overlaps with the in-process schedule.
async function runBackgroundDispatch() {
  if (runningDispatch) return;
  if (Date.now() < firestoreQuotaBlockedUntil) return;

  runningDispatch = (async () => {
    let reminders;
    let automaticAttendance;
    try {
      automaticAttendance = await processAutomaticAttendance();
      reminders = await queueAttendanceReminders();
    } catch (error) {
      // A reminder query failure must not stop approvals, tasks, and other
      // pending notifications from being delivered.
      console.error('Background attendance reminder scan failed:', error);
      reminders = { error: String(error.message || error) };
      if (isFirestoreQuotaError(error)) {
        pauseForFirestoreQuota(error);
        return { reminders, push: { skipped: 'firestore_quota_exhausted' } };
      }
    }

    if (reminders?.queued > 0 || automaticAttendance?.found > 0) {
      schedulePushDispatch('scheduled_work');
    }
    return { automaticAttendance, reminders };
  })();

  try {
    const result = await runningDispatch;
    diagnostics.lastReminderAt = new Date().toISOString();
    diagnostics.lastReminderResult = result;
    if (result.reminders?.queued || result.automaticAttendance?.found) {
      console.log('Background notification dispatch:', result);
    }
  } catch (error) {
    console.error('Background notification dispatch failed:', error);
    diagnostics.lastReminderAt = new Date().toISOString();
    diagnostics.lastReminderResult = { error: String(error.message || error) };
  } finally {
    runningDispatch = null;
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (url.pathname === '/' || url.pathname === '/health') {
    sendJson(res, 200, {
      ok: true,
      service: 'zawolf-notification-dispatcher',
      notificationListener: notificationUnsubscribe ? 'connected' : 'starting',
      firestoreQuotaBlockedUntil: firestoreQuotaBlockedUntil
        ? new Date(firestoreQuotaBlockedUntil).toISOString()
        : null,
      diagnostics,
      time: new Date().toISOString(),
    });
    return;
  }

  if (url.pathname === '/dispatch') {
    await handleDispatch(req, res, url);
    return;
  }

  if (url.pathname === '/attendance-reminders') {
    await handleAttendanceReminders(req, res, url);
    return;
  }

  sendJson(res, 404, { ok: false, error: 'Not found' });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`ZaWolf notification dispatcher listening on port ${port}`);
  // Firestore wakes the push dispatcher as soon as a notification document is
  // created. Scheduled work remains on a five-minute clock for attendance.
  startNotificationListener();
  setTimeout(() => void runBackgroundDispatch(), 5000);
  setInterval(() => void runBackgroundDispatch(), backgroundIntervalMs);
  setInterval(
    () => schedulePushDispatch('hourly_fallback'),
    pushFallbackIntervalMs,
  );
});
