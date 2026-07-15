const http = require('http');
const { URL } = require('url');
const { dispatchNotifications } = require('./dispatch-notifications');
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
let runningDispatch = null;
let firestoreQuotaBlockedUntil = 0;

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
    sendJson(res, 200, { ok: true, ...(await runningDispatch) });
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

    let push;
    try {
      push = await dispatchNotifications();
    } catch (error) {
      if (isFirestoreQuotaError(error)) pauseForFirestoreQuota(error);
      throw error;
    }
    return { automaticAttendance, reminders, push };
  })();

  try {
    const result = await runningDispatch;
    if (result.reminders.queued || result.push.found) {
      console.log('Background notification dispatch:', result);
    }
  } catch (error) {
    console.error('Background notification dispatch failed:', error);
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
  // Run shortly after a deploy, then every five minutes. The reminder scanner
  // uses a ten-minute delivery window, so this avoids Firestore quota-heavy
  // minute polling without missing a scheduled reminder.
  setTimeout(() => void runBackgroundDispatch(), 5000);
  setInterval(() => void runBackgroundDispatch(), backgroundIntervalMs);
});
