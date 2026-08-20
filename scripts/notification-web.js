const http = require('http');
const { URL } = require('url');
const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const {
  dispatchNotifications,
  watchPendingNotifications,
  initializeFirebase,
} = require('./dispatch-notifications');
const { createRuntimeLease } = require('./runtime-lease');
const { queueAttendanceReminders } = require('./attendance-reminders');
const { processAutomaticAttendance } = require('./auto-attendance');
const {
  processManagerLeavePermissionBypasses,
} = require('./manager-leave-permission-bypass');
const { syncSalesKpis } = require('./sync-sales-kpis');
const {
  createGoogleSheetsIntegration,
} = require('./google-sheets-integration');
const {
  submitAttendanceAction,
  bindAttendanceDevice,
  resolveCheckInStatus,
} = require('./attendance-gateway');
const {
  canManageCheckoutPolicy,
  checkoutDisabledResult,
  loadCheckoutPolicy,
  updateCheckoutPolicy,
} = require('./checkout-policy');

const port = Number(process.env.PORT || 3000);
const dispatchSecret = process.env.NOTIFICATION_DISPATCH_SECRET || '';
const defaultGoogleWorkspaceOrigins = [
  'https://zawolf-hr-system-60317.web.app',
  'https://zawolf-hr-system-60317.firebaseapp.com',
];
const googleWorkspaceAllowedOrigins = new Set(
  String(process.env.GOOGLE_WORKSPACE_ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
    .concat(defaultGoogleWorkspaceOrigins),
);
const backgroundIntervalMs = Math.max(
  5 * 60 * 1000,
  Number(process.env.NOTIFICATION_DISPATCH_INTERVAL_MS || 5 * 60 * 1000),
);
const backgroundSchedulerEnabled =
  process.env.NOTIFICATION_BACKGROUND_SCHEDULER_ENABLED !== 'false';
const quotaBackoffMs = Math.max(
  15 * 60 * 1000,
  Number(process.env.FIRESTORE_QUOTA_BACKOFF_MS || 60 * 60 * 1000),
);
const pushFallbackIntervalMs = Math.max(
  30 * 60 * 1000,
  Number(process.env.NOTIFICATION_FALLBACK_INTERVAL_MS || 60 * 60 * 1000),
);
const salesKpiSyncIntervalMs = Math.max(
  6 * 60 * 60 * 1000,
  Number(process.env.SALES_KPI_SYNC_INTERVAL_MS || 24 * 60 * 60 * 1000),
);
let runningDispatch = null;
let runningSalesKpiSync = null;
let firestoreQuotaBlockedUntil = 0;
let pendingDispatchTimer = null;
let notificationUnsubscribe = null;
let notificationListenerOwner = false;
let runtimeLease = null;
let googleSheetsIntegration = null;
const googleSheetsRoleCache = new Map();
const GOOGLE_SHEETS_ALLOWED_ROLES = new Set([
  'hr_admin',
  'hr_manager',
  'super_admin',
]);
const diagnostics = {
  lastPushAt: null,
  lastPushResult: null,
  lastReminderAt: null,
  lastReminderResult: null,
  lastSalesKpiAt: null,
  lastSalesKpiResult: null,
  listenerError: null,
  lastGoogleWorkspaceAuthError: null,
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

function getRuntimeLease() {
  if (!runtimeLease) {
    initializeFirebase();
    runtimeLease = createRuntimeLease(admin.firestore(), admin, {
      leaseMs: Math.max(7 * 60 * 1000, backgroundIntervalMs + 60 * 1000),
    });
  }
  return runtimeLease;
}

async function withRuntimeLease(name, task) {
  const lease = getRuntimeLease();
  if (!(await lease.acquire(name))) {
    return { skipped: 'another_worker_running' };
  }
  try {
    return await task();
  } finally {
    await lease.release(name).catch((error) => {
      console.warn(`Could not release runtime lease ${name}:`, error);
    });
  }
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
  runningDispatch = withRuntimeLease(
    'notification_dispatch',
    () => dispatchNotifications(),
  );
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
  void ensureNotificationListenerLeader();
}

async function ensureNotificationListenerLeader() {
  try {
    if (!(await getRuntimeLease().acquire('notification_listener'))) {
      if (notificationUnsubscribe) notificationUnsubscribe();
      notificationUnsubscribe = null;
      notificationListenerOwner = false;
      return;
    }
    notificationListenerOwner = true;
    if (notificationUnsubscribe) return;
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
          () => void ensureNotificationListenerLeader(),
          quotaError ? quotaBackoffMs : 60 * 1000,
        );
      },
    });
  } catch (error) {
    notificationListenerOwner = false;
    diagnostics.listenerError = String(error.message || error);
    console.error('Could not start pending notification listener:', error);
    notificationUnsubscribe = null;
    setTimeout(() => void ensureNotificationListenerLeader(), 60 * 1000);
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

function sendBinary(res, payload) {
  const safeName = String(payload.fileName || 'download')
    .replace(/[\r\n"]/g, '_');
  res.writeHead(200, {
    'content-type': payload.mimeType || 'application/octet-stream',
    'content-length': payload.contents.length,
    'content-disposition': `attachment; filename*=UTF-8''${encodeURIComponent(safeName)}`,
    'cache-control': 'private, no-store',
    'x-content-type-options': 'nosniff',
  });
  res.end(payload.contents);
}

function applyGoogleWorkspaceCors(req, res) {
  const origin = String(req.headers.origin || '');
  let isTrustedZaWolfOrigin = false;
  try {
    const parsed = new URL(origin);
    isTrustedZaWolfOrigin = parsed.protocol === 'https:' &&
      (parsed.hostname === 'zawolf.ai' || parsed.hostname.endsWith('.zawolf.ai'));
  } catch (_) {}
  if (!googleWorkspaceAllowedOrigins.has(origin) && !isTrustedZaWolfOrigin) return false;
  res.setHeader('access-control-allow-origin', origin);
  res.setHeader('access-control-allow-methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  res.setHeader('access-control-allow-headers', 'Authorization, Content-Type');
  res.setHeader(
    'access-control-expose-headers',
    'Content-Disposition, Content-Type',
  );
  res.setHeader('access-control-max-age', '600');
  res.setHeader('vary', 'Origin');
  return true;
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

function getGoogleSheetsIntegration() {
  if (!googleSheetsIntegration) {
    googleSheetsIntegration = createGoogleSheetsIntegration();
  }
  return googleSheetsIntegration;
}

async function authorizeGoogleSheetsRequest(req) {
  // The server-to-server secret is useful for the first Hostinger smoke test.
  // Mobile/web clients must use their Firebase ID token instead.
  if (isAuthorized(req)) return { uid: 'system', role: 'super_admin' };

  const authHeader = String(req.headers.authorization || '');
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';
  if (!token) return null;

  const firebaseApp = initializeFirebase();
  // A normal ID-token verification validates the signature, issuer, audience,
  // and expiration. The previous revoked-token lookup required an additional
  // Firebase Auth Admin permission on Hostinger and rejected otherwise-valid
  // browser sessions. The active Firestore account + role check below still
  // denies disabled or non-HR users.
  const decoded = await getAuth(firebaseApp).verifyIdToken(token);
  const cached = googleSheetsRoleCache.get(decoded.uid);
  if (cached && cached.expiresAt > Date.now()) {
    diagnostics.lastGoogleWorkspaceAuthError = null;
    return cached.user;
  }

  const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
  const data = userDoc.data() || {};
  if (!userDoc.exists || data.isActive !== true || !GOOGLE_SHEETS_ALLOWED_ROLES.has(data.role)) {
    return null;
  }
  const user = { uid: decoded.uid, role: data.role };
  googleSheetsRoleCache.set(decoded.uid, {
    user,
    expiresAt: Date.now() + 5 * 60 * 1000,
  });
  diagnostics.lastGoogleWorkspaceAuthError = null;
  return user;
}

async function authorizeWorkspaceRequest(req) {
  if (isAuthorized(req)) return { uid: 'system', role: 'super_admin' };
  const authHeader = String(req.headers.authorization || '');
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';
  if (!token) return null;
  const firebaseApp = initializeFirebase();
  const decoded = await getAuth(firebaseApp).verifyIdToken(token);
  const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
  const data = userDoc.data() || {};
  if (!userDoc.exists || data.isActive !== true) return null;
  return {
    uid: decoded.uid,
    role: String(data.role || ''),
    department: String(data.department || ''),
    position: String(data.position || ''),
  };
}

function isWorkspaceItManager(actor) {
  if (actor?.role !== 'manager') return false;
  const unit = `${actor.department || ''} ${actor.position || ''}`.toLowerCase();
  return unit.includes('information technology') ||
    /(^|[^a-z])it([^a-z]|$)/.test(unit) ||
    unit.includes('تكنولوجيا المعلومات') ||
    unit.includes('تقنية المعلومات') ||
    unit.includes('قسم تقنية') ||
    unit.includes('قسم it');
}

function isWorkspaceController(actor) {
  return actor?.role === 'super_admin' || isWorkspaceItManager(actor);
}

async function authorizeAttendanceRequest(req) {
  const authHeader = String(req.headers.authorization || '');
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';
  if (!token) return null;
  const firebaseApp = initializeFirebase();
  const decoded = await getAuth(firebaseApp).verifyIdToken(token);
  return { uid: decoded.uid };
}

async function authorizeCheckoutPolicyRequest(req) {
  if (isAuthorized(req)) return { uid: 'system', role: 'super_admin' };
  const authHeader = String(req.headers.authorization || '');
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';
  if (!token) return null;
  const decoded = await getAuth(initializeFirebase()).verifyIdToken(token);
  const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
  const data = userDoc.data() || {};
  if (!userDoc.exists || data.isActive !== true) return null;
  return { uid: decoded.uid, role: String(data.role || '') };
}

async function handleAttendanceGateway(req, res) {
  try {
    const actor = await authorizeAttendanceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'unauthenticated', error: 'يرجى تسجيل الدخول مرة أخرى.' });
      return;
    }
    const body = await readJsonBody(req, 16 * 1024);
    if (body.action?.type === 'checkOut') {
      const policy = await loadCheckoutPolicy(admin.firestore());
      if (!policy.enabled) {
        sendJson(res, 200, {
          ok: true,
          ...checkoutDisabledResult({
            attendanceId: String(body.action?.attendanceId || ''),
            policy,
          }),
        });
        return;
      }
    }
    const result = body.action?.type === 'bindDevice'
      ? await bindAttendanceDevice({ admin, actor, rawAction: body.action })
      : await submitAttendanceAction({ admin, actor, rawAction: body.action });
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const code = String(error.code || 'attendance_unavailable');
    const status = ['device_conflict', 'device_mismatch', 'account_inactive'].includes(code)
      ? 409
      : ['unauthenticated'].includes(code)
        ? 401
        : 400;
    console.error('Attendance gateway failed:', code, error.message || error);
    sendJson(res, status, {
      ok: false,
      code,
      error: String(error.message || 'تعذر تأكيد الحضور الآن.'),
    });
  }
}

async function handleCheckoutPolicy(req, res) {
  try {
    const actor = await authorizeCheckoutPolicyRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'unauthenticated', error: 'يرجى تسجيل الدخول مرة أخرى.' });
      return;
    }
    if (req.method === 'GET') {
      const policy = await loadCheckoutPolicy(admin.firestore());
      sendJson(res, 200, {
        ok: true,
        ...policy,
        policy,
        canManage: canManageCheckoutPolicy(actor),
      });
      return;
    }
    if (req.method !== 'POST') {
      sendJson(res, 405, { ok: false, code: 'method_not_allowed', error: 'الطريقة غير مدعومة.' });
      return;
    }
    const body = await readJsonBody(req, 8 * 1024);
    const policy = await updateCheckoutPolicy({
      db: admin.firestore(), admin, actor,
      enabled: body.enabled,
      expectedRevision: body.expectedRevision,
      reason: body.reason,
    });
    sendJson(res, 200, { ok: true, ...policy, policy, canManage: true });
  } catch (error) {
    const code = String(error.code || 'checkout_policy_unavailable');
    const status = code === 'not_authorized' ? 403 : code === 'policy_conflict' ? 409 : 400;
    sendJson(res, status, {
      ok: false,
      code,
      error: String(error.message || 'تعذر تحديث حالة تسجيل الانصراف.'),
    });
  }
}

async function handleAttendanceStatus(req, res) {
  try {
    const actor = await authorizeAttendanceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'unauthenticated', error: 'يرجى تسجيل الدخول مرة أخرى.' });
      return;
    }
    const body = await readJsonBody(req, 4 * 1024);
    const result = await resolveCheckInStatus({
      admin,
      actor,
      attendanceId: body.attendanceId,
    });
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const code = String(error.code || 'attendance_unavailable');
    const status = code === 'unauthenticated' ? 401 : 400;
    console.error('Attendance status lookup failed:', code, error.message || error);
    sendJson(res, status, {
      ok: false,
      code,
      error: 'تعذر التحقق من حالة الحضور الآن.',
    });
  }
}

async function workspaceResourceFor(actor, resourceId, { edit = false, download = false } = {}) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(resourceId || ''))) {
    const error = new Error('Workspace resource id is invalid.');
    error.code = 'not_found';
    throw error;
  }
  const db = admin.firestore();
  const resourceRef = db.collection('workspaceResources').doc(resourceId);
  const [resourceDoc, secretDoc, grantDoc] = await Promise.all([
    resourceRef.get(),
    db.collection('workspaceResourceSecrets').doc(resourceId).get(),
    db.collection('workspaceAccessGrants').doc(`${resourceId}_${actor.uid}`).get(),
  ]);
  const resource = resourceDoc.data() || {};
  const secret = secretDoc.data() || {};
  const grant = grantDoc.data() || {};
  const managers = Array.isArray(resource.managerIds) ? resource.managerIds : [];
  const isAdmin = isWorkspaceController(actor);
  const isResourceManager = actor.role === 'manager' && managers.includes(actor.uid);
  const grantPermission = String(grant.permission || '');
  const hasGrant = grant.isActive === true && ['view', 'download', 'edit'].includes(grantPermission);
  const canEdit = isAdmin || isResourceManager || (hasGrant && grantPermission === 'edit');
  const canDownload = isAdmin || isResourceManager ||
    (hasGrant && ['download', 'edit'].includes(grantPermission));
  const canView = isAdmin || isResourceManager || hasGrant;
  const allowed = edit ? canEdit : download ? canDownload : canView;
  if (!resourceDoc.exists || resource.isActive !== true || !secret.externalId || !allowed) {
    const error = new Error('You do not have access to this company resource.');
    error.code = 'forbidden';
    throw error;
  }
  return {
    resource,
    externalId: String(secret.externalId),
    canEdit,
    canDownload,
    isController: isAdmin,
    isResourceManager,
  };
}

function parseWorkspaceFolderPath(rawPath) {
  const path = String(rawPath || '').trim();
  if (!path) return [];
  const ids = path.split(',').map((value) => decodeURIComponent(value).trim());
  if (ids.length > 12 || ids.some((id) => !/^[A-Za-z0-9_-]{10,}$/.test(id))) {
    throw new Error('Workspace folder path is invalid.');
  }
  return ids;
}

// Never trust a Drive id supplied by the client. Every path part is verified
// as a direct child of the previous folder before it is used.
async function resolvedWorkspaceFolder(item, rawPath) {
  if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
  let folderId = item.externalId;
  for (const expectedId of parseWorkspaceFolderPath(rawPath)) {
    const children = await getGoogleSheetsIntegration().listWorkspaceFolder(folderId);
    const child = children.find((file) => String(file.id) === expectedId &&
      String(file.mimeType) === 'application/vnd.google-apps.folder');
    if (!child) {
      const error = new Error('You do not have access to this folder.');
      error.code = 'forbidden';
      throw error;
    }
    folderId = expectedId;
  }
  return folderId;
}

async function workspaceSheetTarget(item, fileId, rawPath) {
  if (item.resource.type === 'sheet') {
    if (fileId && String(fileId) !== item.externalId) {
      const error = new Error('You do not have access to this Sheet.');
      error.code = 'forbidden';
      throw error;
    }
    return { spreadsheetId: item.externalId, name: item.resource.name };
  }
  const folderId = await resolvedWorkspaceFolder(item, rawPath);
  const children = await getGoogleSheetsIntegration().listWorkspaceFolder(folderId);
  const file = children.find((child) => String(child.id) === String(fileId) &&
    String(child.mimeType) === 'application/vnd.google-apps.spreadsheet');
  if (!file) {
    const error = new Error('You do not have access to this Sheet.');
    error.code = 'forbidden';
    throw error;
  }
  return { spreadsheetId: String(file.id), name: String(file.name || '') };
}

async function recordWorkspaceAudit(actor, action, resourceId, resourceName, metadata = {}) {
  await admin.firestore().collection('workspaceAuditLogs').add({
    actorId: actor.uid,
    actorName: String(actor.displayName || actor.name || ''),
    actorEmail: String(actor.email || ''),
    actorEmployeeId: String(actor.employeeId || ''),
    action,
    resourceId,
    resourceName: String(resourceName || ''),
    metadata,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function handleCompanyWorkspace(req, res, url) {
  let actor;
  try {
    actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    const parts = url.pathname.split('/').filter(Boolean);
    // /company-workspace/resources/:resourceId/sheet[/rows/:rowNumber]
    if (parts.length < 4 || parts[0] !== 'company-workspace' || parts[1] !== 'resources') {
      sendJson(res, 404, { ok: false, error: 'Not found' });
      return;
    }
    const resourceId = decodeURIComponent(parts[2]);
    const action = parts[3];
    if (action === 'sheet' && req.method === 'GET') {
      const item = await workspaceResourceFor(actor, resourceId);
      const target = await workspaceSheetTarget(item, url.searchParams.get('fileId'), url.searchParams.get('path'));
      const profileId = String(item.resource.schemaProfileId || '');
      const profile = profileId
        ? (await admin.firestore().collection('workspaceSchemaProfiles').doc(profileId).get()).data() || {}
        : {};
      const sheet = await getGoogleSheetsIntegration().readWorkspaceSheet({
        spreadsheetId: target.spreadsheetId,
        tabName: url.searchParams.get('tabName') || item.resource.sheetTab || '',
        headerRow: Number(profile.headerRow || 1),
      });
      const editableFields = item.isController || item.isResourceManager
        ? sheet.headers
        : (Array.isArray(profile.editableFields) ? profile.editableFields : []);
      await recordWorkspaceAudit(actor, 'sheet_viewed', resourceId, target.name || item.resource.name, { type: 'sheet' });
      sendJson(res, 200, {
        ok: true,
        tabName: sheet.tabName,
        tabs: sheet.tabs || [sheet.tabName],
        headers: sheet.headers,
        headerCells: sheet.headerCells || [],
        merges: sheet.merges || [],
        rows: sheet.rows.slice(0, 500),
        // An edit grant follows normal Google Sheets expectations: values,
        // formatting, rows, columns, and worksheet tabs can all be changed.
        editableFields: item.canEdit ? sheet.headers : editableFields,
        capabilities: {
          edit: item.canEdit,
          structure: item.canEdit,
          format: item.canEdit,
        },
      });
      return;
    }
    if (action === 'sheet' && parts[4] === 'rows' && req.method === 'PATCH') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      const target = await workspaceSheetTarget(item, url.searchParams.get('fileId'), url.searchParams.get('path'));
      const rowNumber = decodeURIComponent(parts[5] || '');
      const body = await readJsonBody(req);
      const profileId = String(item.resource.schemaProfileId || '');
      const profile = profileId
        ? (await admin.firestore().collection('workspaceSchemaProfiles').doc(profileId).get()).data() || {}
        : {};
      const sheet = await getGoogleSheetsIntegration().readWorkspaceSheet({
        spreadsheetId: target.spreadsheetId,
        tabName: body.tabName || item.resource.sheetTab || '',
        headerRow: Number(profile.headerRow || 1),
      });
      await getGoogleSheetsIntegration().updateWorkspaceSheetRow({
        spreadsheetId: target.spreadsheetId,
        tabName: sheet.tabName,
        rowNumber,
        headers: sheet.headers,
        updates: body.updates,
        editableHeaders: item.canEdit ? sheet.headers : [],
      });
      await recordWorkspaceAudit(actor, 'sheet_cells_edited', resourceId, item.resource.name, {
        rowNumber, fields: Object.keys(body.updates || {}).slice(0, 30),
      });
      sendJson(res, 200, { ok: true });
      return;
    }
    if (action === 'sheet' && parts[4] === 'format' && req.method === 'POST') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      const body = await readJsonBody(req);
      const target = await workspaceSheetTarget(item, url.searchParams.get('fileId'), url.searchParams.get('path'));
      const sheet = await getGoogleSheetsIntegration().readWorkspaceSheet({
        spreadsheetId: target.spreadsheetId,
        tabName: body.tabName || item.resource.sheetTab || '',
        headerRow: 1,
      });
      await getGoogleSheetsIntegration().formatWorkspaceSheetRange({
        spreadsheetId: target.spreadsheetId,
        tabName: sheet.tabName,
        startRow: body.startRow,
        endRow: body.endRow || body.startRow,
        startColumn: body.startColumn,
        endColumn: body.endColumn || body.startColumn,
        backgroundColor: body.backgroundColor,
        textColor: body.textColor,
        bold: body.bold,
        italic: body.italic,
        horizontalAlignment: body.horizontalAlignment,
        wrapStrategy: body.wrapStrategy,
        dropdownValues: body.dropdownValues,
        checkbox: body.checkbox,
        clearValidation: body.clearValidation,
        clearFormatting: body.clearFormatting,
      });
      await recordWorkspaceAudit(actor, 'sheet_format_changed', resourceId, item.resource.name, {
        tabName: sheet.tabName, startRow: body.startRow, endRow: body.endRow || body.startRow,
        startColumn: body.startColumn, endColumn: body.endColumn || body.startColumn,
      });
      sendJson(res, 200, { ok: true });
      return;
    }
    if (action === 'sheet' && parts[4] === 'structure' && req.method === 'POST') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      const body = await readJsonBody(req);
      const target = await workspaceSheetTarget(item, url.searchParams.get('fileId'), url.searchParams.get('path'));
      const sheet = await getGoogleSheetsIntegration().readWorkspaceSheet({
        spreadsheetId: target.spreadsheetId,
        tabName: body.tabName || item.resource.sheetTab || '',
        headerRow: 1,
      });
      await getGoogleSheetsIntegration().changeWorkspaceSheetStructure({
        spreadsheetId: target.spreadsheetId,
        tabName: sheet.tabName,
        operation: body.operation,
        index: body.index,
        count: body.count,
        headerRow: body.headerRow,
        headerValue: body.headerValue,
      });
      await recordWorkspaceAudit(actor, 'sheet_structure_changed', resourceId, item.resource.name, {
        tabName: sheet.tabName, operation: body.operation, index: body.index,
        count: body.count || 1, headerValue: String(body.headerValue || '').slice(0, 200),
      });
      sendJson(res, 200, { ok: true });
      return;
    }
    if (action === 'sheet' && parts[4] === 'tabs' && req.method === 'POST') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      const body = await readJsonBody(req);
      const target = await workspaceSheetTarget(item, url.searchParams.get('fileId'), url.searchParams.get('path'));
      const result = await getGoogleSheetsIntegration().changeWorkspaceSheetTab({
        spreadsheetId: target.spreadsheetId,
        operation: body.operation,
        tabName: body.tabName,
        newName: body.newName,
      });
      await recordWorkspaceAudit(actor, 'sheet_tabs_changed', resourceId, item.resource.name, {
        operation: String(body.operation || ''),
        tabName: String(body.tabName || '').slice(0, 100),
        newName: String(body.newName || '').slice(0, 100),
      });
      sendJson(res, 200, { ok: true, tabName: result.tabName });
      return;
    }
    if (action === 'files' && parts.length === 4 && req.method === 'GET') {
      const item = await workspaceResourceFor(actor, resourceId);
      if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
      const folderId = await resolvedWorkspaceFolder(item, url.searchParams.get('path'));
      const files = await getGoogleSheetsIntegration().listWorkspaceFolder(folderId);
      await recordWorkspaceAudit(actor, 'folder_viewed', resourceId, item.resource.name, {
        type: 'folder', path: parseWorkspaceFolderPath(url.searchParams.get('path')).length,
      });
      sendJson(res, 200, {
        ok: true,
        files,
        capabilities: {
          edit: item.canEdit,
          download: item.canDownload,
          manage: item.isController || item.isResourceManager,
        },
      });
      return;
    }
    if (action === 'files' && parts[5] === 'content' && req.method === 'GET') {
      const item = await workspaceResourceFor(actor, resourceId, { download: true });
      if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
      const fileId = decodeURIComponent(parts[4] || '');
      const folderId = await resolvedWorkspaceFolder(item, url.searchParams.get('path'));
      const payload = await getGoogleSheetsIntegration().downloadWorkspaceDriveFile({
        folderId,
        fileId,
      });
      await recordWorkspaceAudit(actor, 'resource_downloaded', resourceId, item.resource.name, {
        fileId: payload.metadata.id,
        fileName: payload.metadata.name,
      });
      sendBinary(res, payload);
      return;
    }
    if (action === 'files' && req.method === 'POST') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
      const body = await readJsonBody(req, 29 * 1024 * 1024);
      const folderId = await resolvedWorkspaceFolder(item, url.searchParams.get('path'));
      const file = await getGoogleSheetsIntegration().uploadWorkspaceDriveFile({
        parentFolderId: folderId,
        name: body.name,
        mimeType: body.mimeType,
        contentsBase64: body.contentsBase64,
      });
      await recordWorkspaceAudit(actor, 'file_uploaded', resourceId, item.resource.name, {
        fileId: file.id,
        fileName: file.name,
      });
      sendJson(res, 201, { ok: true, file: {
        id: file.id, name: file.name, mimeType: file.mimeType,
        modifiedTime: file.modifiedTime, size: file.size,
      } });
      return;
    }
    if (action === 'folders' && req.method === 'POST') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
      const body = await readJsonBody(req);
      const folderId = await resolvedWorkspaceFolder(item, url.searchParams.get('path'));
      const folder = await getGoogleSheetsIntegration().createWorkspaceDriveFolder({
        parentFolderId: folderId,
        name: body.name,
      });
      await recordWorkspaceAudit(actor, 'folder_created', resourceId, item.resource.name, {
        fileId: folder.id,
        fileName: folder.name,
      });
      sendJson(res, 201, { ok: true, folder });
      return;
    }
    if (action === 'files' && parts[4] && req.method === 'PATCH') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
      const body = await readJsonBody(req);
      const folderId = await resolvedWorkspaceFolder(item, url.searchParams.get('path'));
      const file = await getGoogleSheetsIntegration().renameWorkspaceDriveFile({
        parentFolderId: folderId,
        fileId: decodeURIComponent(parts[4]),
        name: body.name,
      });
      await recordWorkspaceAudit(actor, 'file_renamed', resourceId, item.resource.name, {
        fileId: file.id,
        fileName: file.name,
      });
      sendJson(res, 200, { ok: true, file: {
        id: file.id, name: file.name, mimeType: file.mimeType,
        modifiedTime: file.modifiedTime, size: file.size,
      } });
      return;
    }
    if (action === 'files' && parts[4] && req.method === 'DELETE') {
      const item = await workspaceResourceFor(actor, resourceId, { edit: true });
      if (item.resource.type !== 'folder') throw new Error('Resource is not a Drive folder.');
      const fileId = decodeURIComponent(parts[4]);
      const folderId = await resolvedWorkspaceFolder(item, url.searchParams.get('path'));
      await getGoogleSheetsIntegration().trashWorkspaceDriveFile({
        parentFolderId: folderId,
        fileId,
      });
      await recordWorkspaceAudit(actor, 'file_deleted', resourceId, item.resource.name, { fileId });
      sendJson(res, 200, { ok: true });
      return;
    }
    sendJson(res, 405, { ok: false, error: 'Method not allowed' });
  } catch (error) {
    const status = error.code === 'forbidden' ? 403 : error.code === 'not_found' ? 404 :
      String(error.message || '') === 'Unauthorized' ? 401 : 400;
    console.error('Company workspace request failed:', error.message || error);
    sendJson(res, status, { ok: false, error: String(error.message || error) });
  }
}

async function syncCompanyWorkspace(actor) {
  if (!isWorkspaceController(actor)) {
    const error = new Error('Only system administrators and IT managers can discover company files.');
    error.code = 'forbidden';
    throw error;
  }
  const connector = getGoogleSheetsIntegration();
  const rootFolderId = connector.config.workspaceRootFolderId;
  if (!rootFolderId) throw new Error('GOOGLE_WORKSPACE_ROOT_FOLDER_ID is missing.');
  const db = admin.firestore();
  const [nodes, secretsSnap, usersSnap, grantsSnap] = await Promise.all([
    connector.discoverWorkspaceTree(rootFolderId),
    db.collection('workspaceResourceSecrets').limit(1500).get(),
    // Legacy employees can have no isActive field.  They are active unless
    // explicitly disabled, so do not omit their company workspace records.
    db.collection('users').limit(1000).get(),
    db.collection('workspaceAccessGrants').limit(1500).get(),
  ]);
  const existingByExternalId = new Map();
  secretsSnap.docs.forEach((doc) => {
    const externalId = String(doc.data().externalId || '');
    if (externalId) existingByExternalId.set(externalId, doc.id);
  });
  const users = usersSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((user) => user.isActive !== false);
  // Employee codes are expected to be unique, but legacy/system accounts can
  // share one.  A folder named "HR-201 - فاتن مجدي ماهر" must never be
  // assigned to a different account merely because it was read last.
  const usersByCode = new Map();
  for (const user of users.filter((item) => item.employeeId)) {
    const code = String(user.employeeId).trim().toUpperCase();
    const candidates = usersByCode.get(code) || [];
    candidates.push(user);
    usersByCode.set(code, candidates);
  }
  const systemSyncGrantsByResource = new Map();
  grantsSnap.docs.forEach((doc) => {
    const grant = doc.data() || {};
    if (String(grant.grantedByName || '') !== 'System sync') return;
    const resourceId = String(grant.resourceId || '');
    if (!resourceId) return;
    const values = systemSyncGrantsByResource.get(resourceId) || [];
    values.push({ id: doc.id, ...grant });
    systemSyncGrantsByResource.set(resourceId, values);
  });
  let created = 0;
  let updated = 0;
  let grants = 0;
  let batch = db.batch();
  let writes = 0;
  const commit = async () => {
    if (!writes) return;
    await batch.commit();
    batch = db.batch();
    writes = 0;
  };
  for (const node of nodes) {
    const mimeType = String(node.mimeType || '');
    const type = mimeType === 'application/vnd.google-apps.folder'
      ? 'folder'
      : mimeType === 'application/vnd.google-apps.spreadsheet'
        ? 'sheet'
        : 'file';
    const pathUpper = String(node.path || '').toUpperCase();
    const matchedCandidates = [...usersByCode.entries()]
      .find(([code]) => pathUpper.includes(code))?.[1] || [];
    const employee = matchedCandidates.find((candidate) => {
      const name = String(candidate.displayName || '').trim().toUpperCase();
      return name.length >= 3 && pathUpper.includes(name);
    }) || (matchedCandidates.length === 1 ? matchedCandidates[0] : null);
    const managerIds = employee
      ? (Array.isArray(employee.managerIds) && employee.managerIds.length
        ? employee.managerIds : (employee.managerId ? [employee.managerId] : []))
      : [];
    const pathParts = String(node.path || '').split('/').filter(Boolean);
    const department = String(
      employee?.department ||
      (pathParts[0] === '03_ملفات_الموظفين' ? pathParts[1] : pathParts[0]) ||
      '',
    );
    const resourceId = existingByExternalId.get(String(node.id || '')) || db.collection('workspaceResources').doc().id;
    const resourceRef = db.collection('workspaceResources').doc(resourceId);
    batch.set(resourceRef, {
      name: String(node.name || ''),
      type,
      provider: 'google_workspace',
      department,
      description: String(node.path || ''),
      schemaProfileId: '',
      sheetTab: '',
      managerIds,
      isActive: true,
      hasExternalId: true,
      syncStatus: 'discovered',
      createdBy: actor.uid,
      updatedBy: actor.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(existingByExternalId.has(String(node.id || '')) ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    }, { merge: true });
    batch.set(db.collection('workspaceResourceSecrets').doc(resourceId), {
      externalId: String(node.id || ''), provider: 'google_workspace',
      updatedBy: actor.uid, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    writes += 2;
    if (existingByExternalId.has(String(node.id || ''))) updated += 1;
    else created += 1;
    if (employee) {
      batch.set(db.collection('workspaceAccessGrants').doc(`${resourceId}_${employee.id}`), {
        resourceId, resourceName: String(node.name || ''), userId: employee.id,
        userName: String(employee.displayName || ''), employeeCode: String(employee.employeeId || ''),
        department: String(employee.department || ''), permission: 'edit',
        grantedBy: actor.uid, grantedByName: 'System sync',
        managerId: String(employee.managerId || ''), isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      writes += 1;
      grants += 1;
      // Correct earlier automatic grants made before duplicate employee-code
      // handling existed. Manually granted access is never touched.
      for (const previous of systemSyncGrantsByResource.get(resourceId) || []) {
        if (String(previous.userId || '') === employee.id) continue;
        batch.set(db.collection('workspaceAccessGrants').doc(previous.id), {
          isActive: false,
          revokedBy: actor.uid,
          revokedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        writes += 1;
      }
    }
    if (writes >= 390) await commit();
  }
  await commit();
  await recordWorkspaceAudit(actor, 'resources_discovered', 'root', 'Google Workspace root', {
    discovered: nodes.length, created, updated, grants,
  });
  return { discovered: nodes.length, created, updated, grants };
}

async function handleCompanyWorkspaceDiscovery(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    const result = await syncCompanyWorkspace(actor);
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const status = error.code === 'forbidden' ? 403 : String(error.message || '') === 'Unauthorized' ? 401 : 400;
    console.error('Company workspace discovery failed:', error.message || error);
    sendJson(res, status, { ok: false, error: String(error.message || error) });
  }
}

async function bootstrapCompanyWorkspace(actor) {
  if (!isWorkspaceController(actor)) {
    const error = new Error('Only system administrators and IT managers can create the company workspace.');
    error.code = 'forbidden';
    throw error;
  }
  const db = admin.firestore();
  const lockRef = db.collection('systemLocks').doc('company_workspace_bootstrap');
  const lockToken = `${actor.uid}_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  await db.runTransaction(async (transaction) => {
    const lock = await transaction.get(lockRef);
    const expiresAt = lock.data()?.expiresAt;
    const isLocked = expiresAt?.toMillis?.() > Date.now();
    if (isLocked) {
      const error = new Error('Company workspace creation is already running. Please wait.');
      error.code = 'workspace_busy';
      throw error;
    }
    transaction.set(lockRef, {
      token: lockToken,
      startedBy: actor.uid,
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  try {
    const usersSnap = await db.collection('users').limit(1000).get();
    const employees = usersSnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((user) => user.isActive !== false);
    const skippedWithoutEmployeeId = employees
      .filter((user) => !String(user.employeeId || '').trim())
      .length;
    const structure = await getGoogleSheetsIntegration().ensureCompanyWorkspaceStructure({
      departments: employees.map((employee) => employee.department),
      employees,
    });
    // Immediately register the resulting folders and employee grants in ZaWolf.
    // Discovery never moves, renames, shares, or deletes anything in Drive.
    const discovery = await syncCompanyWorkspace(actor);
    await recordWorkspaceAudit(actor, 'workspace_structure_created', 'root', 'Google Workspace root', {
      createdFolders: structure.created,
      departmentFolders: structure.departmentFolders,
      employeeFolders: structure.employeeFolders,
      skippedWithoutEmployeeId,
      discovered: discovery.discovered,
    });
    return { structure, discovery };
  } finally {
    await db.runTransaction(async (transaction) => {
      const lock = await transaction.get(lockRef);
      if (lock.data()?.token === lockToken) transaction.delete(lockRef);
    }).catch(() => {});
  }
}

async function handleCompanyWorkspaceBootstrap(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    const result = await bootstrapCompanyWorkspace(actor);
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const status = error.code === 'forbidden' ? 403 : error.code === 'workspace_busy' ? 409 :
      String(error.message || '') === 'Unauthorized' ? 401 : 400;
    console.error('Company workspace bootstrap failed:', error.message || error);
    sendJson(res, status, { ok: false, error: String(error.message || error) });
  }
}

async function handleWorkspaceAuditReport(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    if (!isWorkspaceController(actor)) {
      const error = new Error('Only system administrators and IT managers can generate the audit report.');
      error.code = 'forbidden';
      throw error;
    }
    const body = await readJsonBody(req);
    const end = body.endDate ? new Date(`${body.endDate}T23:59:59.999Z`) : new Date();
    const start = body.startDate ? new Date(`${body.startDate}T00:00:00.000Z`) :
      new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) {
      throw new Error('Audit report date range is invalid.');
    }
    const db = admin.firestore();
    const snapshot = await db.collection('workspaceAuditLogs')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(end))
      .orderBy('createdAt', 'desc')
      .limit(2000)
      .get();
    const actorIds = [...new Set(snapshot.docs.map((doc) => String(doc.data().actorId || '')).filter(Boolean))];
    const userDocs = await Promise.all(actorIds.map((id) => db.collection('users').doc(id).get()));
    const users = new Map(userDocs.map((doc) => [doc.id, doc.data() || {}]));
    const actionLabel = (action) => ({
      resource_created: 'إضافة مصدر', resource_updated: 'تعديل مصدر',
      access_granted: 'منح وصول', access_revoked: 'إلغاء وصول',
      sheet_viewed: 'عرض Sheet', sheet_cells_edited: 'تعديل خلايا',
      sheet_format_changed: 'تنسيق خلايا', sheet_structure_changed: 'تعديل صفوف أو أعمدة',
      resource_downloaded: 'تنزيل', file_uploaded: 'رفع ملف',
      folder_created: 'إنشاء مجلد', file_renamed: 'إعادة تسمية',
      file_deleted: 'حذف ملف', folder_viewed: 'عرض مجلد',
    }[action] || String(action || 'عرض'));
    const rows = snapshot.docs.map((doc) => {
      const data = doc.data();
      const user = users.get(String(data.actorId || '')) || {};
      const date = data.createdAt?.toDate?.();
      const metadata = data.metadata && typeof data.metadata === 'object'
        ? JSON.stringify(data.metadata) : '';
      return [
        date ? date.toISOString() : '',
        String(data.actorName || user.displayName || user.name || ''),
        String(data.actorEmployeeId || user.employeeId || ''),
        String(data.actorEmail || user.email || ''),
        actionLabel(data.action),
        String(data.resourceName || ''),
        metadata,
      ];
    });
    const report = await getGoogleSheetsIntegration().writeWorkspaceAuditReport(
      ['التاريخ والوقت', 'المستخدم', 'كود الموظف', 'البريد', 'الإجراء', 'الملف أو المصدر', 'التفاصيل'],
      rows,
    );
    const resourceId = 'workspace_audit_report';
    const batch = db.batch();
    batch.set(db.collection('workspaceResources').doc(resourceId), {
      name: report.reportName,
      type: 'sheet',
      department: 'التقارير',
      description: 'سجل تدقيق مركزي لجميع عمليات العرض والتعديل والتنزيل في Workspace.',
      hasExternalId: true,
      schemaProfileId: '',
      sheetTab: report.tabTitle,
      managerIds: [],
      isActive: true,
      syncStatus: 'connected',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(db.collection('workspaceResourceSecrets').doc(resourceId), {
      externalId: report.spreadsheetId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await recordWorkspaceAudit(actor, 'audit_report_generated', resourceId, report.reportName, {
      startDate: body.startDate || '', endDate: body.endDate || '', rowCount: rows.length,
    });
    sendJson(res, 200, {
      ok: true,
      rowCount: report.rowCount,
      resource: {
        id: resourceId,
        name: report.reportName,
        type: 'sheet',
        department: 'التقارير',
        description: 'سجل تدقيق Workspace',
        hasExternalId: true,
        schemaProfileId: '',
        sheetTab: report.tabTitle,
        managerIds: [],
        isActive: true,
        syncStatus: 'connected',
      },
    });
  } catch (error) {
    const status = error.code === 'forbidden' ? 403 :
      String(error.message || '') === 'Unauthorized' ? 401 : 400;
    console.error('Workspace audit report failed:', error.message || error);
    sendJson(res, status, { ok: false, error: String(error.message || error) });
  }
}

async function readJsonBody(req, maxBytes = 32 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let bytes = 0;
    let tooLarge = false;
    req.on('data', (chunk) => {
      bytes += chunk.length;
      if (bytes > maxBytes) {
        tooLarge = true;
        return;
      }
      if (!tooLarge) chunks.push(chunk);
    });
    req.on('end', () => {
      if (tooLarge) {
        const error = new Error('Request body is too large.');
        error.code = 'body_too_large';
        reject(error);
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'));
      } catch (_) {
        reject(new Error('Request body must contain valid JSON.'));
      }
    });
    req.on('error', reject);
  });
}

async function handleGoogleSheets(req, res, url) {
  let actor;
  try {
    actor = await authorizeGoogleSheetsRequest(req);
  } catch (error) {
    diagnostics.lastGoogleWorkspaceAuthError = String(error.code || error.message || error);
    console.warn('Google Sheets request authentication failed:', error.message || error);
    sendJson(res, 401, { ok: false, error: 'Unauthorized' });
    return;
  }
  if (!actor) {
    sendJson(res, 403, { ok: false, error: 'HR or admin access is required.' });
    return;
  }

  try {
    if (url.pathname === '/google-sheets/reports/daily' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const dateKey = String(body.date || '').trim();
      if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
        sendJson(res, 400, { ok: false, error: 'A valid report date is required.' });
        return;
      }
      // Query a loose UTC lower bound, then compare calendar dates in Cairo.
      // Egypt observes daylight-saving time, so a fixed +02:00 boundary can
      // incorrectly exclude leave records stored at local midnight in summer.
      const looseLeaveEnd = new Date(`${dateKey}T00:00:00.000Z`);
      looseLeaveEnd.setUTCDate(looseLeaveEnd.getUTCDate() - 1);
      const cairoDateKey = (value) => {
        const date = value?.toDate?.();
        if (!date) return '';
        return new Intl.DateTimeFormat('en-CA', {
          year: 'numeric', month: '2-digit', day: '2-digit',
          timeZone: 'Africa/Cairo',
        }).format(date);
      };
      const db = admin.firestore();
      const [usersSnap, attendanceSnap, permissionsSnap, leavesSnap] =
        await Promise.all([
          db.collection('users').where('isActive', '==', true).get(),
          db.collection('attendance').where('date', '==', dateKey).get(),
          db.collection('permissions').where('requestDate', '==', dateKey).get(),
          db.collection('leaves')
            .where('endDate', '>=', admin.firestore.Timestamp.fromDate(looseLeaveEnd))
            .get(),
        ]);
      const attendanceByUser = new Map();
      attendanceSnap.docs.forEach((doc) => {
        const data = doc.data();
        attendanceByUser.set(String(data.userId || ''), data);
      });
      const permissionByUser = new Map();
      permissionsSnap.docs.forEach((doc) => {
        const data = doc.data();
        if (data.status === 'approved') {
          const values = permissionByUser.get(String(data.userId || '')) || [];
          values.push(data);
          permissionByUser.set(String(data.userId || ''), values);
        }
      });
      const leaveByUser = new Map();
      leavesSnap.docs.forEach((doc) => {
        const data = doc.data();
        const leaveStartKey = cairoDateKey(data.startDate);
        const leaveEndKey = cairoDateKey(data.endDate);
        if (data.status === 'approved' &&
            leaveStartKey && leaveStartKey <= dateKey &&
            leaveEndKey && leaveEndKey >= dateKey) {
          leaveByUser.set(String(data.userId || ''), data);
        }
      });
      const time = (value) => {
        const date = value?.toDate?.();
        return date
          ? new Intl.DateTimeFormat('ar-EG', {
              hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Cairo',
            }).format(date)
          : '';
      };
      const permissionLabel = (type) => ({
        early_leave: 'مغادرة مبكرة',
        late_arrival: 'تأخير حضور',
        mid_shift_exit: 'خروج أثناء الدوام',
      }[type] || String(type || ''));
      const leaveLabel = (type) => ({
        annual: 'إجازة سنوية',
        day_off: 'يوم إجازة',
        sick: 'إجازة مرضية',
        casual: 'إجازة عارضة',
        unpaid: 'إجازة بدون راتب',
        exam: 'إجازة امتحان',
        remote: 'عمل عن بُعد',
      }[type] || String(type || ''));
      const headers = [
        'التاريخ', 'كود الموظف', 'اسم الموظف', 'القسم', 'الحالة',
        'وقت الحضور', 'وقت الانصراف', 'دقائق التأخير', 'الإذن',
        'الإجازة', 'نسبة الخصم', 'آخر تحديث',
      ];
      const rows = usersSnap.docs
        .map((doc) => {
          const user = doc.data();
          const attendance = attendanceByUser.get(doc.id) || {};
          const permissions = permissionByUser.get(doc.id) || [];
          const leave = leaveByUser.get(doc.id);
          const status = leave
            ? 'إجازة'
            : attendance.status === 'present' || attendance.checkInTime
              ? 'حاضر'
              : permissions.length > 0
                ? 'إذن معتمد/لم يسجل'
              : 'غائب/لم يسجل';
          return [
            dateKey,
            user.employeeId || '',
            user.displayName || '',
            user.department || '',
            status,
            time(attendance.checkInTime),
            time(attendance.checkOutTime),
            Number(attendance.lateMinutes || 0),
            permissions.map((item) => permissionLabel(item.permissionType)).join('، '),
            leaveLabel(leave?.leaveType),
            Number(attendance.salaryDeductionFraction || 0),
            new Date().toISOString(),
          ];
        })
        .sort((a, b) => String(a[3]).localeCompare(String(b[3]), 'ar'));
      const report = await getGoogleSheetsIntegration().writeDailyReport(
        dateKey,
        headers,
        rows,
      );
      sendJson(res, 200, { ok: true, report, preview: rows.slice(0, 100) });
      return;
    }
    const basePath = '/google-sheets/test/rows';
    if (url.pathname === basePath && req.method === 'GET') {
      const rows = await getGoogleSheetsIntegration().readRows();
      sendJson(res, 200, { ok: true, rows });
      return;
    }
    if (url.pathname.startsWith(`${basePath}/`) && req.method === 'PATCH') {
      const recordId = decodeURIComponent(url.pathname.slice(basePath.length + 1));
      const body = await readJsonBody(req);
      const row = await getGoogleSheetsIntegration().updateRow(recordId, body);
      sendJson(res, 200, { ok: true, row });
      return;
    }
    sendJson(res, 405, { ok: false, error: 'Method not allowed' });
  } catch (error) {
    const status = error.code === 'not_found'
      ? 404
      : error.code === 'body_too_large'
        ? 413
        : 400;
    console.error('Google Sheets test request failed:', error.message || error);
    sendJson(res, status, { ok: false, error: String(error.message || error) });
  }
}

async function handleGoogleDriveTest(req, res, url) {
  let actor;
  try {
    actor = await authorizeGoogleSheetsRequest(req);
  } catch (error) {
    diagnostics.lastGoogleWorkspaceAuthError = String(error.code || error.message || error);
    console.warn('Google Drive request authentication failed:', error.message || error);
    sendJson(res, 401, { ok: false, error: 'Unauthorized' });
    return;
  }
  if (!actor) {
    sendJson(res, 403, { ok: false, error: 'HR or admin access is required.' });
    return;
  }
  try {
    const basePath = '/google-drive/test';
    const contentPrefix = `${basePath}/files/`;
    if (url.pathname.startsWith(contentPrefix) &&
        url.pathname.endsWith('/content') && req.method === 'GET') {
      const encodedId = url.pathname.slice(
        contentPrefix.length,
        -'/content'.length,
      );
      const fileId = decodeURIComponent(encodedId);
      const payload = await getGoogleSheetsIntegration().downloadDriveFile(fileId);
      sendBinary(res, payload);
      return;
    }
    if (url.pathname === `${basePath}/files` && req.method === 'GET') {
      const files = await getGoogleSheetsIntegration().listDriveFiles();
      sendJson(res, 200, { ok: true, files });
      return;
    }
    if (url.pathname === `${basePath}/file` && req.method === 'POST') {
      const body = await readJsonBody(req);
      const file = await getGoogleSheetsIntegration().createDriveTestFile(
        body.name,
        body.contents,
      );
      sendJson(res, 201, { ok: true, file });
      return;
    }
    sendJson(res, 405, { ok: false, error: 'Method not allowed' });
  } catch (error) {
    const status = error.code === 'body_too_large' || error.code === 'too_large'
      ? 413
      : error.code === 'forbidden'
        ? 403
        : 400;
    console.error('Google Drive test request failed:', error.message || error);
    sendJson(res, status, { ok: false, error: String(error.message || error) });
  }
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
  runningDispatch = withRuntimeLease('background_attendance', async () => {
    const managerLeaveBypasses =
      await processManagerLeavePermissionBypasses();
    const automaticAttendance = await processAutomaticAttendance();
    const push = await dispatchNotifications();
    return { managerLeaveBypasses, automaticAttendance, ...push };
  });
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
  runningDispatch = withRuntimeLease('background_attendance', async () => {
    const managerLeaveBypasses =
      await processManagerLeavePermissionBypasses();
    const automaticAttendance = await processAutomaticAttendance();
    const reminders = await queueAttendanceReminders();
    const push = await dispatchNotifications();
    return { managerLeaveBypasses, automaticAttendance, reminders, push };
  });
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

  runningDispatch = withRuntimeLease('background_attendance', async () => {
    let reminders;
    let automaticAttendance;
    let managerLeaveBypasses;
    try {
      managerLeaveBypasses =
        await processManagerLeavePermissionBypasses();
      automaticAttendance = await processAutomaticAttendance();
      reminders = await queueAttendanceReminders();
    } catch (error) {
      // A reminder query failure must not stop approvals, tasks, and other
      // pending notifications from being delivered.
      console.error('Background attendance reminder scan failed:', error);
      reminders = { error: String(error.message || error) };
      if (isFirestoreQuotaError(error)) {
        pauseForFirestoreQuota(error);
        return {
          managerLeaveBypasses,
          reminders,
          push: { skipped: 'firestore_quota_exhausted' },
        };
      }
    }

    if (reminders?.queued > 0 || automaticAttendance?.found > 0) {
      schedulePushDispatch('scheduled_work');
    }
    return { managerLeaveBypasses, automaticAttendance, reminders };
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

async function runScheduledSalesKpiSync() {
  if (!process.env.SALES_API_KEY || runningSalesKpiSync) return;
  runningSalesKpiSync = withRuntimeLease('sales_kpi_sync', () => syncSalesKpis());
  try {
    const result = await runningSalesKpiSync;
    diagnostics.lastSalesKpiAt = new Date().toISOString();
    diagnostics.lastSalesKpiResult = result;
    console.log('Scheduled Sales KPI sync:', result);
  } catch (error) {
    diagnostics.lastSalesKpiAt = new Date().toISOString();
    diagnostics.lastSalesKpiResult = {
      error: String(error.message || error),
    };
    console.error('Scheduled Sales KPI sync failed:', error);
  } finally {
    runningSalesKpiSync = null;
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const isGoogleWorkspaceRoute =
    url.pathname.startsWith('/google-sheets/') ||
    url.pathname.startsWith('/google-drive/') ||
    url.pathname.startsWith('/company-workspace/');
  const isAttendanceGatewayRoute =
    url.pathname === '/attendance/events' ||
    url.pathname === '/attendance/status' ||
    url.pathname === '/attendance/checkout-policy';

  if ((isGoogleWorkspaceRoute || isAttendanceGatewayRoute) && req.method === 'OPTIONS') {
    if (!applyGoogleWorkspaceCors(req, res)) {
      sendJson(res, 403, { ok: false, error: 'Origin is not allowed.' });
      return;
    }
    res.writeHead(204);
    res.end();
    return;
  }
  if (isGoogleWorkspaceRoute || isAttendanceGatewayRoute) {
    applyGoogleWorkspaceCors(req, res);
  }

  if (url.pathname === '/' || url.pathname === '/health') {
    sendJson(res, 200, {
      ok: true,
      service: 'zawolf-notification-dispatcher',
      notificationListener: notificationListenerOwner && notificationUnsubscribe
        ? 'connected'
        : 'standby',
      backgroundScheduler: backgroundSchedulerEnabled ? 'internal' : 'external_cron',
      workerId: runtimeLease?.owner || null,
      firestoreQuotaBlockedUntil: firestoreQuotaBlockedUntil
        ? new Date(firestoreQuotaBlockedUntil).toISOString()
        : null,
      googleSheets: {
        configured: Boolean(
          process.env.GOOGLE_SHEETS_SERVICE_ACCOUNT &&
          process.env.GOOGLE_SHEETS_TEST_SPREADSHEET_ID
        ),
      },
      googleHrReports: {
        configured: Boolean(process.env.GOOGLE_HR_REPORTS_SPREADSHEET_ID),
      },
      googleDrive: {
        configured: Boolean(
          process.env.GOOGLE_SHEETS_SERVICE_ACCOUNT &&
          process.env.GOOGLE_DRIVE_TEST_FOLDER_ID
        ),
      },
      googleWorkspace: {
        configured: Boolean(
          process.env.GOOGLE_SHEETS_SERVICE_ACCOUNT &&
          process.env.GOOGLE_WORKSPACE_ROOT_FOLDER_ID
        ),
      },
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

  if (url.pathname === '/sales-kpi/sync') {
    if (!isAuthorized(req, url)) {
      sendJson(res, 401, { ok: false, error: 'Unauthorized' });
      return;
    }
    if (runningSalesKpiSync) {
      sendJson(res, 202, {
        ok: true,
        status: 'already_running',
        message: 'A Sales KPI sync is already in progress.',
      });
      return;
    }
    try {
      runningSalesKpiSync = withRuntimeLease('sales_kpi_sync', () =>
        syncSalesKpis({
          startDate: url.searchParams.get('startDate') || undefined,
          endDate: url.searchParams.get('endDate') || undefined,
          company: url.searchParams.get('company') || undefined,
        }),
      );
      const result = await runningSalesKpiSync;
      diagnostics.lastSalesKpiAt = new Date().toISOString();
      diagnostics.lastSalesKpiResult = result;
      sendJson(res, 200, { ok: true, ...result });
    } catch (error) {
      console.error('Sales KPI sync failed:', error);
      diagnostics.lastSalesKpiAt = new Date().toISOString();
      diagnostics.lastSalesKpiResult = {
        error: String(error.message || error),
      };
      sendJson(res, 500, {
        ok: false,
        error: String(error.message || error),
      });
    } finally {
      runningSalesKpiSync = null;
    }
    return;
  }

  if (url.pathname === '/google-sheets/reports/daily' ||
      url.pathname === '/google-sheets/test/rows' ||
      url.pathname.startsWith('/google-sheets/test/rows/')) {
    await handleGoogleSheets(req, res, url);
    return;
  }

  if (url.pathname === '/google-drive/test/files' ||
      (url.pathname.startsWith('/google-drive/test/files/') &&
       url.pathname.endsWith('/content')) ||
      url.pathname === '/google-drive/test/file') {
    await handleGoogleDriveTest(req, res, url);
    return;
  }

  if (url.pathname === '/company-workspace/discover' && req.method === 'POST') {
    await handleCompanyWorkspaceDiscovery(req, res);
    return;
  }

  if (url.pathname === '/company-workspace/bootstrap' && req.method === 'POST') {
    await handleCompanyWorkspaceBootstrap(req, res);
    return;
  }

  if (url.pathname === '/company-workspace/reports/audit' && req.method === 'POST') {
    await handleWorkspaceAuditReport(req, res);
    return;
  }

  if (url.pathname === '/attendance/events' && req.method === 'POST') {
    await handleAttendanceGateway(req, res);
    return;
  }

  if (url.pathname === '/attendance/status' && req.method === 'POST') {
    await handleAttendanceStatus(req, res);
    return;
  }

  if (url.pathname === '/attendance/checkout-policy' &&
      (req.method === 'GET' || req.method === 'POST')) {
    await handleCheckoutPolicy(req, res);
    return;
  }

  if (url.pathname.startsWith('/company-workspace/resources/')) {
    await handleCompanyWorkspace(req, res, url);
    return;
  }

  sendJson(res, 404, { ok: false, error: 'Not found' });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`ZaWolf notification dispatcher listening on port ${port}`);
  // Firestore wakes the push dispatcher as soon as a notification document is
  // created. Scheduled work remains on a five-minute clock for attendance.
  startNotificationListener();
  // Hostinger may briefly run more than one Node worker during deployment or
  // restarts. Renew the lease so exactly one worker retains the listener.
  setInterval(() => void ensureNotificationListenerLeader(), 2 * 60 * 1000);
  if (backgroundSchedulerEnabled) {
    setTimeout(() => void runBackgroundDispatch(), 5000);
    setInterval(() => void runBackgroundDispatch(), backgroundIntervalMs);
  } else {
    console.log('Background attendance scheduler is disabled; expecting external cron.');
  }
  setInterval(
    () => schedulePushDispatch('hourly_fallback'),
    pushFallbackIntervalMs,
  );
  if (process.env.SALES_API_KEY) {
    setTimeout(() => void runScheduledSalesKpiSync(), 30 * 1000);
    setInterval(
      () => void runScheduledSalesKpiSync(),
      salesKpiSyncIntervalMs,
    );
  }
});
