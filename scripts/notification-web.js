const http = require('http');
const { URL } = require('url');
const { dispatchNotifications } = require('./dispatch-notifications');
const { queueAttendanceReminders } = require('./attendance-reminders');

const port = Number(process.env.PORT || 3000);
const dispatchSecret = process.env.NOTIFICATION_DISPATCH_SECRET || '';
let runningDispatch = null;

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
    url.searchParams.get('secret') === dispatchSecret ||
    bearer === dispatchSecret
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
  runningDispatch = dispatchNotifications();
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
    const reminders = await queueAttendanceReminders();
    const push = await dispatchNotifications();
    return { reminders, push };
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
});
