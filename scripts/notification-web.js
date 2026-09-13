const http = require('http');
const crypto = require('crypto');
const { URL } = require('url');
const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const {
  dispatchNotifications,
  watchPendingNotifications,
  watchPendingConversationOutboxes,
  initializeFirebase,
} = require('./dispatch-notifications');
const { oneSignalConfiguration } = require('./onesignal');
const { createRuntimeLease } = require('./runtime-lease');
const { queueAttendanceReminders } = require('./attendance-reminders');
const { processAutomaticAttendance } = require('./auto-attendance');
const {
  processManagerLeavePermissionBypasses,
  reconcileFinalizedPermissions,
} = require('./manager-leave-permission-bypass');
const { syncSalesKpis } = require('./sync-sales-kpis');
const {
  createGoogleSheetsIntegration,
} = require('./google-sheets-integration');
const {
  submitAttendanceAction,
  bindAttendanceDevice,
  resetAttendanceDevice,
  resolveCheckInStatus,
} = require('./attendance-gateway');
const { recordManualAttendance, listManualAttendanceEmployees } = require('./manual-attendance');
const { overrideAutoApprovedCasualLeave, editCasualLeaveDates } = require('./casual-leave-override');
const {
  listRooms,
  saveRoom,
  createMeeting,
  decideMeeting,
  cancelMeeting,
  listMeetingApprovers,
  checkAvailability,
  listMeetingRequests,
} = require('./meeting-requests');
const {
  listRequestTypes: listCustomRequestTypes,
  listCustomRequestDirectory,
  saveRequestType: saveCustomRequestType,
  createCustomRequest,
  decideCustomRequest,
  listCustomRequests,
} = require('./configurable-requests');
const {
  listAssignments: listAttendanceLocationAssignments,
  previewAssignments: previewAttendanceLocationAssignments,
  applyAssignments: applyAttendanceLocationAssignments,
  getAssignmentOperation: getAttendanceLocationOperation,
  loadMultiLocationFlag: loadAttendanceMultiLocationFlag,
} = require('./attendance-location-assignments');
const {
  canManageCheckoutPolicy,
  checkoutDisabledResult,
  loadCheckoutPolicy,
  updateCheckoutPolicy,
} = require('./checkout-policy');
const { workspaceSafeError } = require('./workspace/safe-errors');
const { canAccessWorkspaceResource } = require('./workspace/authorization');
const {
  reserveWorkspaceOperation,
  completeWorkspaceOperation,
} = require('./workspace/operation-idempotency');
const { appendWorkspaceAudit } = require('./workspace/audit');
const { requestContext } = require('./workspace/request-context');
const {
  performWorkspaceDriveOperation,
  uploadGovernedAttachment,
  downloadGovernedAttachment,
} = require('./workspace/drive-operations');
const {
  planWorkspaceSourceImport,
  nextSourceImportRun,
  SOURCE_IMPORT_LEASE_MS,
} = require('./workspace/source-import');
const {
  normalizeWorkspaceGrant,
  grantDocumentId,
} = require('./workspace/access-administration');
const {
  reportKey,
  reportRunId,
  workspaceAuditTabTitle,
  reserveWorkspaceReport,
  completeWorkspaceReport,
  failWorkspaceReport,
} = require('./workspace/reports');
const { buildHrOperationalRows } = require('./workspace/hr-reports');
const { performSpreadsheetMutation } = require('./workspace/spreadsheet-mutations');
const { performSpreadsheetStructure, performSpreadsheetFormat } = require('./workspace/spreadsheet-structure');
const {
  workspaceSheetCompatibility,
  ensureWorkspaceSheetCompatible,
} = require('./workspace/spreadsheet-compatibility');
const {
  validatePageSize,
  validateParentResourceId,
} = require('./workspace/resource-navigation');
const {
  validateViewport,
  verifyExpectedSpreadsheetVersion,
  safeSpreadsheetSnapshot,
} = require('./workspace/spreadsheet-read');
const { recordDiagnosticEvent, sanitizeDiagnosticEvent } = require('./diagnostics');
const { PHASE007_FLAGS, isPhase007FlagEnabled } = require('./feature-flags');
const { routeCompanyOsRequest } = require('./company-os/router');
const {
  normalizeDeveloperToolScopes,
  isDeveloperToolsExpiryValid,
  isDeveloperToolsEntitlementActive,
} = require('./developer-tools-entitlement');
const {
  buildRequestNotification,
  employeeUserIdFromRequest,
  managerUserIds,
  recipientUserIds,
  normalizeRequestNotificationInput,
  requestEmployeeName,
} = require('./request-management-notifications');
const {
  canManageDeveloperTools,
  canManageOperationalVisibility,
  canReviewAttendanceSecurity,
  canManageSalesMappings,
  canViewDiagnostics,
  isHrOrAdmin,
} = require('./phase007-authorization');
const {
  canonicalSalesFilters,
  salesFilterVersion,
  mappingDocumentId,
} = require('./sales-indicators');
const {
  isValidCorrectionSubmission,
  isSameCairoAttendanceDay,
} = require('./attendance-correction-operation');
const {
  markAllNotificationsRead,
  resolveNotificationDestination,
} = require('./notification-operations');
const {
  safeId: safeConversationId,
  normalizeMemberIds,
  isConversationMember,
  normalizeMessageInput,
  normalizeAttachmentInput,
  canStartConversation,
  canAccessDepartment,
  departmentKey,
  normalizeDepartmentName,
} = require('./conversation-operations');
const {
  safeUserId: safeOperationalUserId,
  safePageSize: safeOperationalPageSize,
  normalizePeriod: normalizeOperationalPeriod,
  canInspectEmployee,
  normalizeTimelineRows,
} = require('./operational-visibility');
const { operationCorsHeaderValue } = require('./http-cors');
const {
  createFieldMission,
  createEmployeeFieldMission,
  decideFieldMission,
} = require('./request-approval-routing');

const port = Number(process.env.PORT || 3000);
const notificationRuntimeRelease = '2026-09-10-instant-notifications-1';
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
const defaultPhase007FlagConfig = {
  conversations_rich_chat_v1: { enabled: true, everyone: true },
};
let phase007FlagConfig = { ...defaultPhase007FlagConfig };
try {
  const configuredFlags = JSON.parse(process.env.PHASE007_FEATURE_FLAGS_JSON || '{}');
  phase007FlagConfig = configuredFlags && typeof configuredFlags === 'object'
    ? { ...defaultPhase007FlagConfig, ...configuredFlags }
    : { ...defaultPhase007FlagConfig };
} catch (_) {
  // Invalid remote configuration preserves the default production flags.
  phase007FlagConfig = { ...defaultPhase007FlagConfig };
}
// Company OS has completed owner approval for production availability. These
// switches only expose the product surfaces: every route still enforces the
// actor role and its specific capability before reading or mutating data.
// Environment configuration may explicitly narrow or disable any slice as an
// immediate, non-destructive rollback control.
const defaultCompanyOsFlagConfig = {
  company_os_portal_v1: { enabled: true, everyone: true },
  company_os_it_v1: { enabled: true, everyone: true },
  company_os_requests_v1: { enabled: true, everyone: true },
  company_os_operations_v1: { enabled: true, everyone: true },
  company_os_organization_v1: { enabled: true, everyone: true },
  company_os_multi_tree_v1: { enabled: true, everyone: true },
};
let companyOsFlagConfig = { ...defaultCompanyOsFlagConfig };
try {
  const configuredFlags = JSON.parse(process.env.COMPANY_OS_FEATURE_FLAGS_JSON || '{}');
  companyOsFlagConfig = configuredFlags && typeof configuredFlags === 'object'
    ? { ...defaultCompanyOsFlagConfig, ...configuredFlags }
    : { ...defaultCompanyOsFlagConfig };
} catch (_) {
  // Preserve the approved organization defaults if optional JSON is invalid.
}
const backgroundIntervalMs = Math.max(
  5 * 60 * 1000,
  Number(process.env.NOTIFICATION_DISPATCH_INTERVAL_MS || 5 * 60 * 1000),
);
const backgroundSchedulerEnabled =
  process.env.NOTIFICATION_BACKGROUND_SCHEDULER_ENABLED !== 'false';
const notificationListenerEnabled =
  process.env.NOTIFICATION_LISTENER_ENABLED !== 'false';
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
let conversationOutboxUnsubscribe = null;
let runtimeLease = null;
let googleSheetsIntegration = null;
const googleSheetsRoleCache = new Map();
const GOOGLE_SHEETS_ALLOWED_ROLES = new Set([
  'hr',
  'hr_admin',
  'hr_manager',
  'hr_officer',
  'hr_specialist',
  'hr_coordinator',
  'admin',
  'administrator',
  'super_admin',
  'owner',
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
  // Safe operational metadata only. Detailed provider errors stay in private
  // Hostinger runtime logs and are never included in a browser response.
  workspace: { lastFailureAt: null, lastFailureArea: null, lastFailureCode: null },
};

function recordWorkspaceDiagnostic(area, error) {
  diagnostics.workspace = {
    lastFailureAt: new Date().toISOString(),
    lastFailureArea: String(area || 'unknown').slice(0, 80),
    lastFailureCode: String(error?.message || error?.code || error?.statusCode || error?.status || 'unknown').slice(0, 120),
  };
}

// `/health` is intentionally safe to expose to the browser. It must help the
// owner distinguish "the sales source is not configured" from a stale or
// failed sync without exposing the provider key or provider error details.
function salesAnalyticsHealth() {
  const result = diagnostics.lastSalesKpiResult;
  let lastSyncStatus = 'never_run';
  if (result) {
    lastSyncStatus = result.error ? 'failed' :
      result.skipped ? 'skipped' : 'completed';
  }
  return {
    configured: Boolean(process.env.SALES_API_KEY),
    baseUrlConfigured: Boolean(process.env.SALES_API_BASE_URL),
    scheduled: Boolean(process.env.SALES_API_KEY),
    syncRunning: Boolean(runningSalesKpiSync),
    lastSyncAt: diagnostics.lastSalesKpiAt,
    lastSyncStatus,
  };
}

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

function schedulePushDispatch(reason = 'firestore_trigger', delayMs = 0) {
  // New notifications are time-sensitive. Firestore may take a moment to
  // invoke its listener, but once it does, begin provider delivery in the
  // same event turn instead of adding a server-side debounce delay.
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
      if (conversationOutboxUnsubscribe) conversationOutboxUnsubscribe();
      notificationUnsubscribe = null;
      conversationOutboxUnsubscribe = null;
      notificationListenerOwner = false;
      return;
    }
    notificationListenerOwner = true;
    if (notificationUnsubscribe && conversationOutboxUnsubscribe) return;
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
    conversationOutboxUnsubscribe = watchPendingConversationOutboxes({
      onPending: (count) => {
        diagnostics.listenerError = null;
        console.log(`Firestore conversation notification trigger received ${count} new outbox item(s).`);
        schedulePushDispatch('conversation_outbox_trigger', 0);
      },
      onError: (error) => {
        diagnostics.listenerError = String(error.message || error);
        console.error('Conversation notification outbox listener failed:', error);
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
    isTrustedZaWolfOrigin = (parsed.protocol === 'https:' || parsed.protocol === 'http:') &&
      (parsed.hostname === 'zawolf.ai' ||
       parsed.hostname.endsWith('.zawolf.ai') ||
       parsed.hostname.endsWith('.web.app') ||
       parsed.hostname.endsWith('.firebaseapp.com') ||
       parsed.hostname === 'localhost' ||
       parsed.hostname === '127.0.0.1');
  } catch (_) {}
  if (!googleWorkspaceAllowedOrigins.has(origin) && !isTrustedZaWolfOrigin) {
    if (!origin) {
      res.setHeader('access-control-allow-origin', '*');
      return true;
    }
  }
  res.setHeader('access-control-allow-origin', origin || '*');
  res.setHeader('access-control-allow-methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('access-control-allow-headers', operationCorsHeaderValue());
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
  const role = String(data.role || '').trim().toLowerCase();
  const hrScope = [
    role,
    data.department,
    data.departmentName,
    data.position,
    data.jobTitle,
    data.job_title,
    data.title,
  ].filter(Boolean).join(' ').toLowerCase();
  const isHrProfile = /(^|\\s)hr([_\\s-]|$)/.test(hrScope) ||
    hrScope.includes('human resource') ||
    hrScope.includes('الموارد البشرية') ||
    hrScope.includes('موارد بشرية') ||
    hrScope.includes('شؤون العاملين');
  if (!userDoc.exists || data.isActive !== true ||
      (!GOOGLE_SHEETS_ALLOWED_ROLES.has(role) && !isHrProfile)) {
    return null;
  }
  const user = { uid: decoded.uid, role };
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
  try {
    const firebaseApp = initializeFirebase();
    const decoded = await getAuth(firebaseApp).verifyIdToken(token);
    const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
    const data = userDoc.data() || {};
    if (!userDoc.exists || data.isActive === false) return null;
    return {
      uid: decoded.uid,
      role: String(data.role || '').trim().toLowerCase(),
      // Support both current and legacy HR profile field names. A valid HR
      // account must not lose access because its profile predates a rename.
      department: String(data.department || data.departmentName || data.departmentId || data.dept || ''),
      position: String(data.position || data.jobTitle || data.job_title || data.title || ''),
      jobTitle: String(data.jobTitle || data.job_title || data.title || data.position || ''),
      displayName: String(data.displayName || data.name || ''),
      name: String(data.name || data.displayName || ''),
      email: String(data.email || decoded.email || ''),
      employeeId: String(data.employeeId || data.employeeCode || data.employee_id || data.code || ''),
      employeeCode: String(data.employeeCode || data.employee_id || data.employeeId || data.code || ''),
      isItManager: data.isItManager === true || data.isITManager === true,
      teamIds: Array.isArray(data.teamIds)
        ? data.teamIds.map((value) => String(value))
        : Array.isArray(data.teams) ? data.teams.map((value) => String(value)) : [],
    };
  } catch (error) {
    console.error('authorizeWorkspaceRequest failed:', error.message || error);
    return null;
  }
}

function actorRole(actor) {
  return String(actor?.role || '').trim().toLowerCase();
}

function workspaceRoleKey(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ');
}

function workspaceActorScope(actor) {
  return workspaceRoleKey([
    actor?.role,
    actor?.department,
    actor?.position,
    actor?.jobTitle,
  ].filter(Boolean).join(' '));
}

function isWorkspaceItManager(actor) {
  if (actor?.isItManager === true) return true;
  if (!['manager', 'it_manager', 'it manager'].includes(actorRole(actor))) return false;
  const unit = `${actor.department || ''} ${actor.position || ''}`.toLowerCase();
  return unit.includes('information technology') ||
    /(^|[^a-z])it([^a-z]|$)/.test(unit) ||
    unit.includes('تكنولوجيا المعلومات') ||
    unit.includes('تقنية المعلومات') ||
    unit.includes('قسم تقنية') ||
    unit.includes('قسم it');
}

function isWorkspaceController(actor) {
  const role = actorRole(actor);
  const normalizedRole = workspaceRoleKey(role);
  const scope = workspaceActorScope(actor);
  return ['super_admin', 'admin', 'administrator', 'owner'].includes(role) ||
    ['super admin', 'system admin', 'system administrator'].includes(normalizedRole) ||
    scope.includes('مسؤول النظام') || scope.includes('مدير النظام') ||
    scope.includes('إدارة النظام') || scope.includes('ادارة النظام') ||
    isWorkspaceItManager(actor);
}

function isWorkspaceHrActor(actor) {
  const role = workspaceRoleKey(actorRole(actor));
  const scope = workspaceActorScope(actor);
  return ['hr', 'hr admin', 'hr manager', 'human resource', 'human resources',
    'human resource manager', 'human resources manager', 'hr officer',
    'hr specialist', 'hr coordinator', 'human resources officer',
    'human resources specialist', 'human resources coordinator'].includes(role) ||
    /(^|\s)hr(\s|$)/.test(scope) ||
    scope.includes('human resource') ||
    scope.includes('الموارد البشرية') ||
    scope.includes('موارد بشرية') ||
    scope.includes('شؤون العاملين');
}

function canViewWorkspaceHrReports(actor) {
  return isWorkspaceController(actor) || isWorkspaceHrActor(actor);
}

function canGenerateWorkspaceAuditReport(actor) {
  return canViewWorkspaceHrReports(actor);
}

function canViewSalesIndicators(actor) {
  const role = actorRole(actor);
  return isWorkspaceController(actor) ||
    isWorkspaceHrActor(actor) ||
    ['manager', 'hr', 'hr_admin', 'hr_manager', 'super_admin', 'admin', 'team_leader'].includes(role);
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
  return {
    uid: decoded.uid,
    role: String(data.role || ''),
    capabilities: Array.isArray(data.capabilities)
      ? data.capabilities.map(String)
      : [],
  };
}

async function handleAttendanceGateway(req, res) {
  let actorId = '';
  let actionType = 'unknown';
  try {
    const actor = await authorizeAttendanceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'unauthenticated', error: 'يرجى تسجيل الدخول مرة أخرى.' });
      return;
    }
    actorId = actor.uid;
    const body = await readJsonBody(req, 16 * 1024);
    actionType = String(body.action?.type || 'unknown');
    console.info('Attendance gateway accepted request:', {
      actorId,
      action: actionType,
      date: String(body.action?.date || '').slice(0, 10),
    });
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
    let result;
    if (body.action?.type === 'bindDevice') {
      result = await bindAttendanceDevice({ admin, actor, rawAction: body.action });
    } else if (body.action?.type === 'resetDevice') {
      const actorDoc = await admin.firestore().collection('users').doc(actor.uid).get();
      const actorData = actorDoc.data() || {};
      if (!actorDoc.exists || actorData.isActive !== true) {
        const error = new Error('يرجى تسجيل الدخول مرة أخرى.');
        error.code = 'unauthenticated';
        throw error;
      }
      result = await resetAttendanceDevice({
        admin,
        actor: {
          uid: actor.uid,
          role: String(actorData.role || ''),
          department: String(actorData.department || ''),
          position: String(actorData.position || ''),
        },
        employeeId: body.action.employeeId,
        reason: body.action.reason,
      });
    } else {
      result = await submitAttendanceAction({ admin, actor, rawAction: body.action });
    }
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const code = String(error.code || 'attendance_unavailable');
    const status = ['device_conflict', 'device_mismatch', 'account_inactive'].includes(code)
      ? 409
      : ['unauthenticated'].includes(code)
        ? 401
        : ['not_authorized'].includes(code)
          ? 403
        : 400;
    // Validation rejections are an expected client outcome. In particular, an
    // expired offline event must not look like a Hostinger runtime failure.
    // Reserve error logs for unavailable/internal gateway faults.
    if (['stale_event', 'invalid_request', 'checkin_missing', 'outside_range',
      'inactive_location', 'assignment_changed', 'device_conflict',
      'device_mismatch', 'account_inactive', 'unauthenticated',
      'not_authorized'].includes(code)) {
      console.info('Attendance gateway rejected:', {
        actorId: actorId || 'unauthenticated',
        code,
        action: actionType,
      });
    } else {
      console.error('Attendance gateway failed:', code, error.message || error);
    }
    const safeMessages = {
      unauthenticated: 'يرجى تسجيل الدخول مرة أخرى.',
      not_authorized: 'لا تملك صلاحية تنفيذ هذه العملية.',
      no_assignment: 'لا يوجد موقع حضور نشط مسند إلى حسابك. تواصل مع HR.',
      assignment_changed: 'تم تحديث مواقع الحضور المسندة. حدّث الصفحة ثم أعد المحاولة.',
      inactive_location: 'موقع الحضور غير نشط حالياً.',
      outside_range: 'أنت خارج نطاق مواقع الحضور المسندة إليك.',
      device_conflict: 'هذا الجهاز مرتبط بحساب حضور آخر.',
      device_mismatch: 'جهاز الحضور المسجل لا يطابق هذا الجهاز.',
      account_inactive: 'حساب الموظف غير نشط.',
    };
    sendJson(res, status, {
      ok: false,
      code,
      error: safeMessages[code] ||
        'تعذر تأكيد الحضور الآن. تحقق من الاتصال ثم أعد المحاولة.',
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
      autoCheckoutReturnGraceMinutes: body.autoCheckoutReturnGraceMinutes,
      companyBreakStartTime: body.companyBreakStartTime,
      companyBreakEndTime: body.companyBreakEndTime,
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

async function handleAttendanceSecurityReview(req, res) {
  try {
    const actor = await authorizeCheckoutPolicyRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'unauthenticated' });
      return;
    }
    if (!canReviewAttendanceSecurity(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    const body = await readJsonBody(req, 8 * 1024);
    const attendanceId = String(body.attendanceId || '').trim();
    const status = String(body.status || '').trim();
    const checkout = body.checkout === true;
    if (!attendanceId || attendanceId.length > 180 || attendanceId.includes('/') ||
        !['approved', 'rejected'].includes(status)) {
      sendJson(res, 400, { ok: false, code: 'validation_failed' });
      return;
    }
    const db = admin.firestore();
    const attendanceRef = db.collection('attendance').doc(attendanceId);
    const statusField = checkout
      ? 'checkoutSecurityReviewStatus'
      : 'securityReviewStatus';
    const changed = await db.runTransaction(async (transaction) => {
      const document = await transaction.get(attendanceRef);
      if (!document.exists) {
        const error = new Error('attendance_not_found');
        error.code = 'not_found';
        throw error;
      }
      const data = document.data() || {};
      if (checkout && data.checkoutPolicyEnabled === false) {
        const error = new Error('checkout_not_applicable');
        error.code = 'checkout_not_applicable';
        throw error;
      }
      if (data[statusField] === status) return false;
      transaction.update(attendanceRef, checkout ? {
        checkoutSecurityReviewStatus: status,
        checkoutSecurityReviewedBy: actor.uid,
        checkoutSecurityReviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      } : {
        securityReviewStatus: status,
        securityReviewedBy: actor.uid,
        securityReviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (changed) {
      const attendance = await attendanceRef.get();
      const userId = String(attendance.data()?.userId || '').trim();
      const operationKey = `${checkout ? 'checkout' : 'checkin'}_${status}`;
      await db.collection('auditLogs')
        .doc(`attendance_security_${attendanceId}_${operationKey}`)
        .set({
          actorId: actor.uid,
          actorRole: actor.role,
          action: `attendance_security_review_${operationKey}`,
          targetCollection: 'attendance',
          targetId: attendanceId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      if (userId) {
        const notificationRef = db.collection('notifications').doc(userId)
          .collection('items')
          .doc(`attendance_security_${attendanceId}_${operationKey}`);
        const existing = await notificationRef.get();
        if (!existing.exists) {
          await notificationRef.create({
            notificationId: notificationRef.id,
            type: 'attendance_security_reviewed',
            title: status === 'approved'
              ? 'تم قبول مراجعة الحضور الأمنية'
              : 'تم رفض مراجعة الحضور الأمنية',
            body: status === 'approved'
              ? 'تم اعتماد حركة الحضور بعد مراجعة مؤشرات الموقع.'
              : 'تم رفض حركة الحضور بعد مراجعة مؤشرات الموقع. تواصل مع HR إذا احتجت توضيحاً.',
            data: {
              route: '/employee/dashboard',
              attendanceId,
            },
            isRead: false,
            pushSent: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          await db.collection('users').doc(userId).set({
            unreadNotifications: admin.firestore.FieldValue.increment(1),
          }, { merge: true });
        }
      }
    }
    sendJson(res, 200, { ok: true, code: changed ? 'updated' : 'unchanged' });
  } catch (error) {
    const code = String(error.code || 'temporarily_unavailable');
    const status = code === 'not_found' ? 404
      : code === 'checkout_not_applicable' ? 409
        : 400;
    sendJson(res, status, { ok: false, code });
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

async function handleAttendanceLocationAssignments(req, res, url) {
  try {
    const actor = await authorizeCheckoutPolicyRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'unauthenticated', error: 'يرجى تسجيل الدخول مرة أخرى.' });
      return;
    }
    let result;
    if (url.pathname === '/attendance/locations/assignments/me' && req.method === 'GET') {
      result = {
        enabled: await loadAttendanceMultiLocationFlag(admin.firestore(), actor.uid),
        assignments: await listAttendanceLocationAssignments({ admin, actor, employeeUid: actor.uid, limit: 20 }),
      };
    } else if (url.pathname === '/attendance/locations/assignments' && req.method === 'GET') {
      result = {
        assignments: await listAttendanceLocationAssignments({
          admin,
          actor,
          employeeUid: url.searchParams.get('employeeUid'),
          limit: url.searchParams.get('limit'),
          all: url.searchParams.get('all') === 'true',
        }),
      };
    } else if (url.pathname === '/attendance/locations/assignments/preview' && req.method === 'POST') {
      result = await previewAttendanceLocationAssignments({ admin, actor, raw: await readJsonBody(req, 32 * 1024) });
    } else if (url.pathname === '/attendance/locations/assignments/apply' && req.method === 'POST') {
      result = await applyAttendanceLocationAssignments({ admin, actor, raw: await readJsonBody(req, 32 * 1024) });
    } else {
      const match = url.pathname.match(/^\/attendance\/locations\/operations\/([^/]+)$/);
      if (!match || req.method !== 'GET') {
        sendJson(res, 404, { ok: false, code: 'not_found' });
        return;
      }
      result = await getAttendanceLocationOperation({ admin, actor, operationId: decodeURIComponent(match[1]) });
    }
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const code = String(error.code || 'temporarily_unavailable');
    const status = Number(error.status) || (code === 'not_authorized' ? 403 : code === 'not_found' ? 404 : code.endsWith('changed') ? 409 : 400);
    console.error('Attendance location operation failed:', code, error.message || error);
    sendJson(res, status, {
      ok: false,
      code,
      error: String(error.messageAr || 'تعذر تنفيذ عملية مواقع الحضور الآن. أعد المحاولة.'),
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
  const [resourceDoc, secretDoc, grantsSnapshot] = await Promise.all([
    resourceRef.get(),
    db.collection('workspaceResourceSecrets').doc(resourceId).get(),
    // Reads and writes must use the same scope-aware grant model. The old
    // direct document lookup made a department/team grant visible in V2 but
    // rejected the same employee when they opened the resource.
    db.collection('workspaceAccessGrants')
      .where('resourceId', '==', String(resourceId))
      .limit(200)
      .get(),
  ]);
  const resource = resourceDoc.data() || {};
  const secret = secretDoc.data() || {};
  const grants = grantsSnapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((grant) => grant.isActive === true);
  const managers = Array.isArray(resource.managerIds) ? resource.managerIds : [];
  const isAdmin = isWorkspaceController(actor);
  // Operational HR reports are generated by ZaWolf and are safe for HR to
  // view even when no individual Drive grant exists. They remain read-only;
  // this exception never applies to employee source files.
  const isHrOperationalReport = resource.department === 'الموارد البشرية' &&
    resource.type === 'sheet' && canViewWorkspaceHrReports(actor);
  const isResourceManager = actor.role === 'manager' && managers.includes(actor.uid);
  const hasCapability = (capability) => canAccessWorkspaceResource({
    actor,
    grants,
    capability,
  });
  const canEdit = isAdmin || isResourceManager || hasCapability('edit');
  const canDownload = isAdmin || isResourceManager || hasCapability('download') || isHrOperationalReport;
  const canView = isAdmin || isResourceManager || hasCapability('view') || isHrOperationalReport;
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

async function listWorkspaceV2Resources(actor, url) {
  const db = admin.firestore();
  const pageSize = validatePageSize(url.searchParams.get('pageSize'));
  let resources = [];
  let grantsByResource = new Map();
  if (isWorkspaceController(actor)) {
    const snapshot = await db.collection('workspaceResources')
      .where('isActive', '==', true).limit(pageSize).get();
    resources = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  } else {
    // Each lookup is bounded and starts from a stable actor attribute.  This
    // avoids a collection-wide workspace-access scan for every page opening.
    const subjectIds = [actor.uid, actor.email, actor.employeeId, actor.department, actor.role]
      .concat(Array.isArray(actor.teamIds) ? actor.teamIds : [])
      .filter(Boolean);
    const snapshots = await Promise.all([
      db.collection('workspaceAccessGrants').where('userId', '==', actor.uid).limit(pageSize).get(),
      ...subjectIds.map((subjectId) => db.collection('workspaceAccessGrants')
        .where('subjectId', '==', subjectId).limit(pageSize).get()),
    ]);
    const byGrantId = new Map();
    snapshots.forEach((snapshot) => snapshot.docs.forEach((doc) => {
      const grant = { id: doc.id, ...doc.data() };
      if (grant.isActive === true) byGrantId.set(doc.id, grant);
    }));
    byGrantId.forEach((grant) => {
      const resourceId = String(grant.resourceId || '');
      if (!resourceId) return;
      const values = grantsByResource.get(resourceId) || [];
      values.push(grant);
      grantsByResource.set(resourceId, values);
    });
    const refs = [...grantsByResource.keys()]
      .slice(0, pageSize)
      .map((resourceId) => db.collection('workspaceResources').doc(resourceId));
    const docs = refs.length ? await db.getAll(...refs) : [];
    resources = docs.filter((doc) => doc.exists).map((doc) => ({ id: doc.id, ...doc.data() }));
    if (canViewWorkspaceHrReports(actor)) {
      const reports = await db.collection('workspaceResources')
        .where('department', '==', 'الموارد البشرية')
        .limit(pageSize)
        .get();
      const known = new Set(resources.map((resource) => resource.id));
      for (const doc of reports.docs) {
        if (doc.data()?.isActive === true && !known.has(doc.id)) {
          resources.push({ id: doc.id, ...doc.data() });
        }
      }
    }
  }
  const parentId = validateParentResourceId(url.searchParams.get('parentId'));
  return resources
    .filter((resource) => !parentId || String(resource.parentResourceId || '') === parentId)
    .filter((resource) => {
      if (resource.isActive !== true) return false;
      return (resource.department === 'الموارد البشرية' && resource.type === 'sheet' &&
        canViewWorkspaceHrReports(actor)) || isWorkspaceController(actor) || canAccessWorkspaceResource({
        actor,
        grants: grantsByResource.get(resource.id) || [],
        capability: 'view',
      });
    })
    .map((resource) => {
      const grants = grantsByResource.get(resource.id) || [];
      const isHrOperationalReport = resource.department === 'الموارد البشرية' &&
        resource.type === 'sheet' && canViewWorkspaceHrReports(actor);
      const capabilities = isWorkspaceController(actor)
        ? ['view', 'download', 'comment', 'edit', 'manage_content', 'manage_access']
        : isHrOperationalReport ? ['view', 'download']
        : ['view', 'download', 'comment', 'edit', 'manage_content', 'manage_access']
          .filter((capability) => canAccessWorkspaceResource({ actor, grants, capability }));
      return {
        id: resource.id,
        name: String(resource.name || ''),
        type: resource.type === 'sheet' ? 'spreadsheet' : String(resource.type || 'file'),
        parentId: resource.parentResourceId || null,
        version: String(resource.updatedAt?.toMillis?.() || resource.syncStatus || 'v1'),
        capabilities,
      };
    });
}

async function handleCompanyWorkspaceV2Resources(req, res, url) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    const resources = await listWorkspaceV2Resources(actor, url);
    recordWorkspaceReadAudit(actor, 'resource_list', 'workspace', 'ملفات الشركة', {
      changeCount: resources.length,
    });
    sendJson(res, 200, { ok: true, resources, nextPageToken: null });
  } catch (error) {
    recordWorkspaceDiagnostic('resource_list', error);
    const safe = workspaceSafeError(error, { writeMayHaveStarted: false });
    console.error('Workspace V2 resource listing failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

const workspacePilotConfigRef = () => admin.firestore()
  .collection('workspaceFeatureFlags').doc('company_workspace_v2');

function normalizeWorkspacePilotConfig(input = {}) {
  const ids = Array.isArray(input.enabledActorIds) ? input.enabledActorIds : [];
  const enabledActorIds = [...new Set(ids
    .map((value) => String(value || '').trim())
    .filter((value) => /^[A-Za-z0-9_-]{1,128}$/.test(value)))]
    .slice(0, 100);
  if (ids.length !== enabledActorIds.length) {
    const error = new Error('Pilot audience is invalid.');
    error.code = 'validation';
    throw error;
  }
  if (typeof input.enabledForEveryone !== 'boolean') {
    const error = new Error('Pilot mode is invalid.');
    error.code = 'validation';
    throw error;
  }
  const reason = String(input.reason || '').trim().slice(0, 250);
  return { enabledForEveryone: input.enabledForEveryone, enabledActorIds, reason };
}

async function handleCompanyWorkspaceV2Pilot(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    const ref = workspacePilotConfigRef();
    if (req.method === 'GET') {
      const current = (await ref.get()).data() || {};
      const enabledActorIds = Array.isArray(current.enabledActorIds)
        ? current.enabledActorIds.map((value) => String(value)) : [];
      const enabled = current.enabledForEveryone === true || enabledActorIds.includes(actor.uid);
      const controller = isWorkspaceController(actor);
      sendJson(res, 200, {
        ok: true,
        enabled,
        canManage: controller,
        ...(controller ? {
          configuration: {
            enabledForEveryone: current.enabledForEveryone === true,
            enabledActorIds,
            updatedAt: current.updatedAt?.toDate?.().toISOString?.() || null,
          },
        } : {}),
      });
      return;
    }
    if (req.method !== 'PUT' || !isWorkspaceController(actor)) {
      const error = new Error('Only system administrators and IT managers can change the pilot.');
      error.code = 'forbidden';
      throw error;
    }
    const config = normalizeWorkspacePilotConfig(await readJsonBody(req, 16 * 1024));
    await ref.set({
      enabledForEveryone: config.enabledForEveryone,
      enabledActorIds: config.enabledActorIds,
      updatedBy: actor.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await appendWorkspaceAudit({
      db: admin.firestore(), actorId: actor.uid, resourceId: 'company_workspace_v2',
      action: 'workspace_pilot_changed',
      details: {
        mode: config.enabledForEveryone ? 'default_v2' : 'limited_pilot',
        audienceCount: config.enabledActorIds.length,
        reason: config.reason || 'not_provided',
      },
    });
    sendJson(res, 200, { ok: true, enabled: config.enabledForEveryone,
      configuration: { ...config } });
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: req.method === 'PUT' });
    console.error('Workspace pilot configuration failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

async function handleCompanyWorkspaceV2Access(req, res, url) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    if (!isWorkspaceController(actor)) {
      const error = new Error('Only system administrators and IT managers can manage access.');
      error.code = 'forbidden';
      throw error;
    }
    const db = admin.firestore();
    const parts = url.pathname.split('/').filter(Boolean);
    const grantId = parts.length === 5 ? String(parts[4]) : '';

    if (req.method === 'GET') {
      const resourceId = validateParentResourceId(url.searchParams.get('resourceId'));
      if (!resourceId) {
        const error = new Error('Workspace resource id is required.');
        error.code = 'validation';
        throw error;
      }
      const grants = await db.collection('workspaceAccessGrants')
        .where('resourceId', '==', resourceId).limit(200).get();
      sendJson(res, 200, {
        ok: true,
        grants: grants.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
      });
      return;
    }

    if (req.method === 'POST') {
      const input = normalizeWorkspaceGrant(await readJsonBody(req, 16 * 1024));
      const resource = await db.collection('workspaceResources').doc(input.resourceId).get();
      if (!resource.exists || resource.data()?.isActive !== true) {
        const error = new Error('Workspace resource was not found.');
        error.code = 'not_found';
        throw error;
      }
      const id = grantDocumentId(input);
      await db.collection('workspaceAccessGrants').doc(id).set({
        ...input,
        isActive: true,
        grantedBy: actor.uid,
        grantedByName: 'ZaWolf Workspace',
        revokedBy: admin.firestore.FieldValue.delete(),
        revokedAt: admin.firestore.FieldValue.delete(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      recordWorkspaceAuditAsync(actor, 'access_changed', input.resourceId, String(resource.data()?.name || ''), {
        change: 'grant_created', scope: input.scope, capability: input.capability,
      });
      sendJson(res, 201, { ok: true, grantId: id });
      return;
    }

    if (req.method === 'DELETE' && /^[A-Za-z0-9_-]{1,128}$/.test(grantId)) {
      const ref = db.collection('workspaceAccessGrants').doc(grantId);
      const grant = await ref.get();
      if (!grant.exists) {
        const error = new Error('Workspace grant was not found.');
        error.code = 'not_found';
        throw error;
      }
      const data = grant.data() || {};
      await ref.set({
        isActive: false,
        revokedBy: actor.uid,
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      recordWorkspaceAuditAsync(actor, 'access_changed', String(data.resourceId || ''), 'صلاحية ملفات الشركة', {
        change: 'grant_revoked', grantId,
      });
      sendJson(res, 200, { ok: true, grantId });
      return;
    }

    sendJson(res, 405, { ok: false, error: 'Method not allowed' });
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: req.method !== 'GET' });
    console.error('Workspace access administration failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

/// V2 source discovery has the same controller authorization as access
/// changes, but unlike the legacy endpoint it always returns a presentation-
/// safe response.  The mobile/web client never receives raw Google/Firebase
/// messages when a large import is unavailable or already in progress.
async function handleCompanyWorkspaceV2SourceImport(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    const result = await syncCompanyWorkspace(actor);
    sendJson(res, 200, { ok: true, ...result });
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: true });
    console.error('Workspace V2 source import failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

function workspaceOperationPayload(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const output = {};
  for (const [key, raw] of Object.entries(value)) {
    if (!/^[A-Za-z][A-Za-z0-9_]{0,40}$/.test(key)) continue;
    if (key === 'cells' && Array.isArray(raw) && raw.length <= 500) {
      output[key] = raw.map((cell) => ({
        row: cell?.row,
        column: cell?.column,
        value: typeof cell?.value === 'string' ? cell.value.slice(0, 10000) : cell?.value,
      }));
    } else if (key === 'dropdownValues' && Array.isArray(raw) && raw.length <= 100) {
      output[key] = raw.map((value) => String(value || '').slice(0, 500));
    } else if (typeof raw === 'string') output[key] = raw.slice(0, 30 * 1024 * 1024);
    else if (typeof raw === 'number' || typeof raw === 'boolean') output[key] = raw;
  }
  return output;
}

function requiredWorkspaceOperationString(payload, key, { maxLength = 512 } = {}) {
  const value = String(payload[key] || '').trim();
  if (!value || value.length > maxLength) {
    const error = new Error('Workspace operation is invalid.');
    error.code = 'validation';
    throw error;
  }
  return value;
}

async function executeWorkspaceV2DriveOperation({ actor, resourceId, kind, payload }) {
  const item = await workspaceResourceFor(actor, resourceId, { edit: true });
  const isContainerOperation = ['fileCreate', 'fileUpload'].includes(kind);
  if (isContainerOperation && item.resource.type !== 'folder') {
    const error = new Error('Workspace resource is not a Drive folder.');
    error.code = 'validation';
    throw error;
  }

  // V2 intentionally accepts stable ZaWolf resource IDs only.  Google Drive
  // IDs and folder paths are private server implementation details; accepting
  // them from a browser would allow a stale or tampered client to target a
  // different Drive item.
  const sourceFolderId = isContainerOperation
    ? item.externalId
    : await workspaceParentFolderId(item);
  let destinationFolderId;
  if (['fileMove', 'fileCopy'].includes(kind)) {
    const destinationResourceId = requiredWorkspaceOperationString(
      payload,
      'destinationResourceId',
      { maxLength: 128 },
    );
    const destination = await workspaceResourceFor(actor, destinationResourceId, { edit: true });
    if (destination.resource.type !== 'folder') {
      const error = new Error('Workspace destination is not a Drive folder.');
      error.code = 'validation';
      throw error;
    }
    destinationFolderId = destination.externalId;
  }
  const providerPayload = isContainerOperation
    ? payload
    : { ...payload, fileId: item.externalId };
  const executed = await performWorkspaceDriveOperation({
    connector: getGoogleSheetsIntegration(),
    sourceFolderId,
    destinationFolderId,
    kind,
    payload: providerPayload,
  });
  if (['fileCreate', 'fileUpload', 'fileCopy'].includes(kind) && executed.result?.id) {
    const parentResourceId = kind === 'fileCopy'
      ? String(payload.destinationResourceId)
      : resourceId;
    await registerWorkspaceCreatedResource({
      actor,
      parentResourceId,
      parentResource: kind === 'fileCopy'
        ? (await workspaceResourceFor(actor, parentResourceId, { edit: true })).resource
        : item.resource,
      providerFile: executed.result,
    });
  }
  if (kind === 'fileRename' && String(executed.result?.name || '').trim()) {
    await admin.firestore().collection('workspaceResources').doc(resourceId).set({
      name: String(executed.result.name).trim(),
      updatedBy: actor.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  if (kind === 'fileMove') {
    const destinationResourceId = String(payload.destinationResourceId);
    await admin.firestore().collection('workspaceResources').doc(resourceId).set({
      parentResourceId: destinationResourceId,
      updatedBy: actor.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  return executed;
}

/// Adds a provider item created by V2 immediately to the internal resource
/// index. A later discovery run reconciles it by its private external ID, so
/// creating a folder never requires the user to click Sync before it appears.
async function registerWorkspaceCreatedResource({
  actor,
  parentResourceId,
  parentResource,
  providerFile,
}) {
  const externalId = String(providerFile?.id || '').trim();
  if (!externalId) return;
  const db = admin.firestore();
  const existing = await db.collection('workspaceResourceSecrets')
    .where('externalId', '==', externalId)
    .limit(1)
    .get();
  if (!existing.empty) return;
  const resourceRef = db.collection('workspaceResources').doc();
  const mimeType = String(providerFile?.mimeType || '');
  const type = mimeType === 'application/vnd.google-apps.folder'
    ? 'folder'
    : mimeType === 'application/vnd.google-apps.spreadsheet'
      ? 'sheet'
      : 'file';
  const grants = await db.collection('workspaceAccessGrants')
    .where('resourceId', '==', parentResourceId)
    .limit(200)
    .get();
  const batch = db.batch();
  batch.set(resourceRef, {
    name: String(providerFile?.name || 'Untitled'),
    type,
    provider: 'google_workspace',
    department: String(parentResource?.department || ''),
    description: '',
    schemaProfileId: '',
    sheetTab: '',
    managerIds: Array.isArray(parentResource?.managerIds) ? parentResource.managerIds : [],
    parentResourceId,
    isActive: true,
    hasExternalId: true,
    syncStatus: 'created_in_workspace_v2',
    createdBy: actor.uid,
    updatedBy: actor.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('workspaceResourceSecrets').doc(resourceRef.id), {
    externalId,
    provider: 'google_workspace',
    updatedBy: actor.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  // Inherit existing scoped access. This preserves the parent folder's access
  // policy without relying on Google Drive links or exposing provider IDs.
  grants.docs.filter((grantDoc) => grantDoc.data()?.isActive === true).forEach((grantDoc) => {
    const grant = grantDoc.data() || {};
    batch.set(db.collection('workspaceAccessGrants').doc(), {
      ...grant,
      resourceId: resourceRef.id,
      resourceName: String(providerFile?.name || 'Untitled'),
      grantedBy: actor.uid,
      grantedByName: 'Workspace inherited access',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  await batch.commit();
}

async function executeWorkspaceV2SpreadsheetOperation({ actor, resourceId, kind, payload }) {
  const item = await workspaceResourceFor(actor, resourceId, { edit: true });
  if (item.resource.type !== 'sheet') {
    const error = new Error('Workspace resource is not a spreadsheet.');
    error.code = 'validation';
    throw error;
  }
  ensureWorkspaceSheetCompatible(item.resource);
  const target = await workspaceSheetTarget(item);
  const requestedTab = String(payload.tabName || item.resource.sheetTab || '').trim();
  // Resolve the tab inside the provider before every edit. It prevents a
  // stale UI from writing to a renamed/deleted worksheet.
  const snapshot = await getGoogleSheetsIntegration().readWorkspaceSheet({
    spreadsheetId: target.spreadsheetId,
    tabName: requestedTab,
    headerRow: 1,
    startRow: Number(payload.expectedStartRow) || undefined,
    startColumn: Number(payload.expectedStartColumn) || undefined,
    rowCount: Number(payload.expectedRowCount) || 1,
    columnCount: Number(payload.expectedColumnCount) || 1,
  });
  const expectedVersion = String(payload.expectedVersion || '').trim();
  verifyExpectedSpreadsheetVersion(expectedVersion, snapshot.version);
  if (kind === 'sheetEdit' || kind === 'sheetPaste') {
    return performSpreadsheetMutation({
      connector: getGoogleSheetsIntegration(), spreadsheetId: target.spreadsheetId,
      tabName: snapshot.tabName, kind, payload,
    });
  }
  if (kind === 'sheetStructure' || kind === 'sheetTab') {
    return performSpreadsheetStructure({
      connector: getGoogleSheetsIntegration(), spreadsheetId: target.spreadsheetId,
      tabName: snapshot.tabName, kind, payload,
    });
  }
  if (kind === 'sheetFormat') {
    return performSpreadsheetFormat({
      connector: getGoogleSheetsIntegration(), spreadsheetId: target.spreadsheetId,
      tabName: snapshot.tabName, payload,
    });
  }
  const error = new Error('Spreadsheet operation is invalid.');
  error.code = 'validation';
  throw error;
}

async function handleCompanyWorkspaceV2Operations(req, res) {
  let reservation;
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    const body = await readJsonBody(req, 29 * 1024 * 1024);
    const context = requestContext(req);
    const operationId = String(body.operationId || context.operationId || '');
    if (!context.operationId || context.operationId !== operationId) {
      const error = new Error('Workspace operation id is invalid.');
      error.code = 'validation';
      throw error;
    }
    const resourceId = requiredWorkspaceOperationString(body, 'resourceId', { maxLength: 128 });
    const kind = requiredWorkspaceOperationString(body, 'kind', { maxLength: 64 });
    const payload = workspaceOperationPayload(body.payload);
    const db = admin.firestore();
    reservation = await reserveWorkspaceOperation({ db, operationId, actorId: actor.uid, resourceId });
    if (reservation.kind === 'replay') {
      sendJson(res, 200, { ok: true, state: reservation.receipt.state, safeMessage: reservation.receipt.safeMessage || null });
      return;
    }
    const executed = ['fileCreate', 'fileUpload', 'fileRename', 'fileMove', 'fileCopy', 'fileTrash', 'fileRestore']
      .includes(kind)
      ? await executeWorkspaceV2DriveOperation({ actor, resourceId, kind, payload })
      : await executeWorkspaceV2SpreadsheetOperation({ actor, resourceId, kind, payload });
    appendWorkspaceAudit({
      db,
      actorId: actor.uid,
      resourceId,
      action: executed.action,
      details: { operationId, source: 'workspace_v2', ...(executed.audit || {}) },
    }).catch((error) => console.warn('Workspace operation audit failed:', error.message || error));
    const receipt = await completeWorkspaceOperation({
      reservation,
      result: { state: 'acknowledged', safeMessage: 'تم حفظ التغيير.' },
    });
    // Provider responses can contain Google Drive IDs and direct links. The
    // client only needs a durable acknowledgement; it reloads the internal
    // resource list to obtain its stable ZaWolf ID.
    sendJson(res, 200, { ok: true, state: receipt.state, safeMessage: receipt.safeMessage });
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: reservation?.kind === 'new' });
    if (reservation?.kind === 'new' && safe.statusCode < 500) {
      await completeWorkspaceOperation({ reservation, result: { state: 'rejected', safeMessage: safe.error } }).catch(() => {});
    }
    console.error('Workspace V2 operation failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

async function handleCompanyWorkspaceV2Download(req, res, url) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    const parts = url.pathname.split('/').filter(Boolean);
    const resourceId = decodeURIComponent(parts[3] || '');
    const item = await workspaceResourceFor(actor, resourceId, { download: true });
    if (item.resource.type === 'folder') {
      const error = new Error('Workspace folders cannot be downloaded.');
      error.code = 'validation';
      throw error;
    }
    const folderId = await workspaceParentFolderId(item);
    const payload = await getGoogleSheetsIntegration().downloadWorkspaceDriveFile({
      folderId,
      fileId: item.externalId,
    });
    // A Drive download must never wait for Firestore before returning bytes to
    // the browser. The event remains best-effort and is retained for reports.
    appendWorkspaceAudit({
      db: admin.firestore(), actorId: actor.uid, resourceId, action: 'file_download',
      details: { source: 'workspace_v2' },
    }).catch((auditError) => console.warn('Workspace download audit failed:', auditError.message || auditError));
    sendBinary(res, payload);
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: false });
    console.error('Workspace V2 download failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

async function handleCompanyWorkspaceV2Sheet(req, res, url) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      const error = new Error('Unauthorized');
      error.statusCode = 401;
      throw error;
    }
    const parts = url.pathname.split('/').filter(Boolean);
    const resourceId = decodeURIComponent(parts[3] || '');
    const item = await workspaceResourceFor(actor, resourceId);
    if (item.resource.type !== 'sheet') {
      const error = new Error('Workspace resource is not a spreadsheet.');
      error.code = 'validation';
      throw error;
    }
    const target = await workspaceSheetTarget(item);
    const viewport = validateViewport({
      startRow: url.searchParams.get('startRow'),
      startColumn: url.searchParams.get('startColumn'),
      rowCount: url.searchParams.get('rowCount'),
      columnCount: url.searchParams.get('columnCount'),
    });
    const sheet = await getGoogleSheetsIntegration().readWorkspaceSheet({
      spreadsheetId: target.spreadsheetId,
      tabName: url.searchParams.get('tabName') || item.resource.sheetTab || '',
      headerRow: 1,
      ...viewport,
    });
    // Reading a sheet is on the interactive path. Record it asynchronously and
    // coalesce repeated viewport reads so scrolling never causes write storms.
    recordWorkspaceReadAudit(
      actor,
      'sheet_read',
      resourceId,
      item.resource.name,
      {
        source: 'workspace_v2',
        tab: sheet.tabName,
        range: `${sheet.tabName}:${viewport.startRow}:${viewport.startColumn}`,
      },
    );
    sendJson(res, 200, {
      ok: true,
      ...safeSpreadsheetSnapshot({
        ...sheet,
        compatibility: workspaceSheetCompatibility(item.resource),
        capabilities: {
          edit: item.canEdit && workspaceSheetCompatibility(item.resource) === 'fullyEditable',
          structure: item.canEdit && workspaceSheetCompatibility(item.resource) === 'fullyEditable',
          format: item.canEdit && workspaceSheetCompatibility(item.resource) === 'fullyEditable',
          validation: item.canEdit && workspaceSheetCompatibility(item.resource) === 'fullyEditable',
          tabs: item.canEdit && workspaceSheetCompatibility(item.resource) === 'fullyEditable',
        },
      }),
    });
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: false });
    console.error('Workspace V2 sheet read failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
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

/// Resolves the parent internally for a V2 resource operation. The only
/// exception is a direct child of the configured company root, whose parent is
/// intentionally not represented as a user-visible Workspace resource.
async function workspaceParentFolderId(item) {
  const parentResourceId = String(item.resource.parentResourceId || '').trim();
  if (!parentResourceId) {
    const rootFolderId = String(getGoogleSheetsIntegration().config.workspaceRootFolderId || '').trim();
    if (!rootFolderId) {
      const error = new Error('Workspace root folder is not configured.');
      error.code = 'unavailable';
      throw error;
    }
    return rootFolderId;
  }
  const parentSecret = await admin.firestore()
    .collection('workspaceResourceSecrets')
    .doc(parentResourceId)
    .get();
  const externalId = String(parentSecret.data()?.externalId || '').trim();
  if (!externalId) {
    const error = new Error('Workspace parent resource is unavailable.');
    error.code = 'not_found';
    throw error;
  }
  return externalId;
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

// Keep audit coverage without making normal Workspace actions wait for a
// Firestore write. A temporary audit failure must never block editing.
function recordWorkspaceAuditAsync(actor, action, resourceId, resourceName, metadata = {}) {
  recordWorkspaceAudit(actor, action, resourceId, resourceName, metadata)
    .catch((error) => console.warn('Workspace audit failed:', error.message || error));
}

// Moving through folders and sheets can issue several read requests in quick
// succession. Keep the audit trail, but do not block the user interface on
// Firestore and collapse repeated reads of the same resource for one minute.
const workspaceReadAuditWindow = new Map();
function recordWorkspaceReadAudit(actor, action, resourceId, resourceName, metadata = {}) {
  const now = Date.now();
  const key = [actor.uid, action, resourceId, metadata.path || '', metadata.tab || ''].join(':');
  const previous = workspaceReadAuditWindow.get(key) || 0;
  if (now - previous < 60000) return;
  workspaceReadAuditWindow.set(key, now);
  if (workspaceReadAuditWindow.size > 5000) {
    for (const [entryKey, recordedAt] of workspaceReadAuditWindow.entries()) {
      if (now - recordedAt > 120000) workspaceReadAuditWindow.delete(entryKey);
    }
  }
  recordWorkspaceAuditAsync(actor, action, resourceId, resourceName, metadata);
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
      recordWorkspaceReadAudit(actor, 'sheet_viewed', resourceId, target.name || item.resource.name, {
        type: 'sheet',
        tab: sheet.tabName,
      });
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
      recordWorkspaceAuditAsync(actor, 'sheet_cells_edited', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'sheet_format_changed', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'sheet_structure_changed', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'sheet_tabs_changed', resourceId, item.resource.name, {
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
      recordWorkspaceReadAudit(actor, 'folder_viewed', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'resource_downloaded', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'file_uploaded', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'folder_created', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'file_renamed', resourceId, item.resource.name, {
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
      recordWorkspaceAuditAsync(actor, 'file_deleted', resourceId, item.resource.name, { fileId });
      sendJson(res, 200, { ok: true });
      return;
    }
    sendJson(res, 405, { ok: false, error: 'Method not allowed' });
  } catch (error) {
    const safe = workspaceSafeError(error, { writeMayHaveStarted: req.method !== 'GET' });
    console.error('Company workspace request failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

async function syncCompanyWorkspace(actor) {
  const db = admin.firestore();
  const runRef = db.collection('workspaceImportRuns').doc('company_workspace_source');
  const token = `${actor.uid}_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const decision = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(runRef);
    const next = nextSourceImportRun(snapshot.data() || {}, { token });
    if (next.kind !== 'busy') {
      transaction.set(runRef, {
        ...next.value,
        startedBy: actor.uid,
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return next;
  });
  if (decision.kind === 'busy') {
    const error = new Error('Company workspace source import is already running.');
    error.code = 'workspace_busy';
    throw error;
  }
  const updateProgress = async (progress) => {
    await runRef.set({
      ...progress,
      token,
      leaseUntilMs: Date.now() + SOURCE_IMPORT_LEASE_MS,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  };
  try {
    const result = await syncCompanyWorkspaceIndex(actor, { onProgress: updateProgress });
    await runRef.set({
      state: 'ready',
      token,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...result,
    }, { merge: true });
    return result;
  } catch (error) {
    await runRef.set({
      state: 'failed_retryable',
      token,
      errorCode: String(error.code || 'unknown').slice(0, 80),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => {});
    throw error;
  }
}

async function syncCompanyWorkspaceIndex(actor, { onProgress = async () => {} } = {}) {
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
  const importPlan = planWorkspaceSourceImport(
    nodes,
    existingByExternalId,
    () => db.collection('workspaceResources').doc().id,
  );
  await onProgress({
    phase: 'reconciling',
    processed: 0,
    total: importPlan.length,
  });
  let processed = 0;
  for (const importItem of importPlan) {
    const { node, resourceId, parentResourceId, existed } = importItem;
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
      // A null parent means the item is directly below the configured company
      // root. This preserves the Drive tree without storing the root itself.
      parentResourceId,
      isActive: true,
      hasExternalId: true,
      syncStatus: 'discovered',
      createdBy: actor.uid,
      updatedBy: actor.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(existed ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    }, { merge: true });
    batch.set(db.collection('workspaceResourceSecrets').doc(resourceId), {
      externalId: String(node.id || ''), provider: 'google_workspace',
      updatedBy: actor.uid, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    writes += 2;
    if (existed) updated += 1;
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
    processed += 1;
    if (processed === importPlan.length || processed % 100 === 0) {
      await onProgress({
        phase: 'reconciling',
        processed,
        total: importPlan.length,
      });
    }
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
    const safe = workspaceSafeError(error, { writeMayHaveStarted: true });
    console.error('Company workspace bootstrap failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

async function handleWorkspaceAuditReport(req, res) {
  let reservation;
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    if (!canGenerateWorkspaceAuditReport(actor)) {
      const error = new Error('Only system administrators, IT managers, and HR can generate the audit report.');
      error.code = 'forbidden';
      throw error;
    }
    const body = await readJsonBody(req);
    const end = body.endDate ? new Date(`${body.endDate}T23:59:59.999Z`) : new Date();
    const start = body.startDate ? new Date(`${body.startDate}T00:00:00.000Z`) :
      new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) {
      const error = new Error('Audit report date range is invalid.');
      error.code = 'validation';
      throw error;
    }
    const db = admin.firestore();
    const key = reportKey({
      type: 'workspace_audit',
      scopeId: 'company',
      startDate: start.toISOString().slice(0, 10),
      endDate: end.toISOString().slice(0, 10),
    });
    reservation = await reserveWorkspaceReport({ db, key, actorId: actor.uid });
    if (reservation.kind === 'replay') {
      sendJson(res, 200, { ok: true, ...reservation.result, replayed: true });
      return;
    }
    if (reservation.kind === 'running') {
      sendJson(res, 202, { ok: true, state: 'generating', message: 'جارٍ إعداد التقرير. أعد التحقق بعد لحظات.' });
      return;
    }
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
      resource_list: 'عرض قائمة الملفات', resource_open: 'فتح ملف أو مجلد',
      access_granted: 'منح وصول', access_revoked: 'إلغاء وصول',
      sheet_viewed: 'عرض Sheet', sheet_cells_edited: 'تعديل خلايا',
      sheet_format_changed: 'تنسيق خلايا', sheet_structure_changed: 'تعديل صفوف أو أعمدة',
      resource_downloaded: 'تنزيل', file_uploaded: 'رفع ملف',
      folder_created: 'إنشاء مجلد', file_renamed: 'إعادة تسمية',
      file_deleted: 'حذف ملف', folder_viewed: 'عرض مجلد',
      sheet_read: 'قراءة Sheet', sheet_edit: 'تعديل خلايا',
      sheet_paste: 'لصق خلايا', sheet_format: 'تنسيق خلايا',
      sheet_structure: 'تعديل صفوف أو أعمدة', sheet_tab: 'تعديل تبويب Sheet',
      file_download: 'تنزيل ملف', file_create: 'إنشاء ملف',
      file_upload: 'رفع ملف', file_move: 'نقل ملف', file_copy: 'نسخ ملف',
      file_trash: 'نقل إلى المهملات', file_restore: 'استعادة ملف',
      access_change: 'تعديل صلاحيات', report_generate: 'إنشاء تقرير',
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
    const period = {
      startDate: start.toISOString().slice(0, 10),
      endDate: end.toISOString().slice(0, 10),
    };
    const report = await getGoogleSheetsIntegration().writeWorkspaceAuditReport(
      ['التاريخ والوقت', 'المستخدم', 'كود الموظف', 'البريد', 'الإجراء', 'الملف أو المصدر', 'التفاصيل'],
      rows,
      { tabTitle: workspaceAuditTabTitle(period) },
    );
    // A report key represents one immutable business period.  Do not reuse a
    // single Workspace resource here: doing so would make a July report point
    // at August data after the next generation run.
    const resourceId = reportRunId(key);
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
    await appendWorkspaceAudit({
      db,
      actorId: actor.uid,
      resourceId,
      action: 'report_generate',
      details: { reportKey: key, changeCount: rows.length },
    });
    const response = {
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
    };
    await completeWorkspaceReport({ reservation, result: response });
    sendJson(res, 200, { ok: true, ...response });
  } catch (error) {
    recordWorkspaceDiagnostic('audit_report', error);
    await failWorkspaceReport({ reservation }).catch(() => {});
    const safe = workspaceSafeError(error, {
      writeMayHaveStarted: reservation?.kind === 'new',
    });
    console.error('Workspace audit report failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

// This endpoint intentionally exposes only the governed audit envelope.  Raw
// provider responses, cell values, formulas and permission secrets never leave
// the server through an activity history view.
async function handleWorkspaceAuditEvents(req, res, url) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    if (!canGenerateWorkspaceAuditReport(actor)) {
      const error = new Error('Only system administrators, IT managers, and HR can view workspace activity.');
      error.code = 'forbidden';
      throw error;
    }
    const startValue = String(url.searchParams.get('startDate') || '').slice(0, 10);
    const endValue = String(url.searchParams.get('endDate') || '').slice(0, 10);
    const end = endValue ? new Date(`${endValue}T23:59:59.999Z`) : new Date();
    const start = startValue ? new Date(`${startValue}T00:00:00.000Z`) :
      new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end ||
        end.getTime() - start.getTime() > 93 * 24 * 60 * 60 * 1000) {
      const error = new Error('Audit activity period is invalid.');
      error.code = 'validation';
      throw error;
    }
    const limit = Math.max(1, Math.min(Number(url.searchParams.get('limit') || 100), 200));
    const snapshot = await admin.firestore().collection('workspaceAuditLogs')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(end))
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();
    const events = snapshot.docs.map((doc) => {
      const data = doc.data() || {};
      const details = data.details && typeof data.details === 'object' ? data.details : {};
      return {
        id: doc.id,
        actorId: String(data.actorId || 'external_unattributed'),
        resourceId: String(data.resourceId || ''),
        action: String(data.action || 'external_activity'),
        occurredAt: data.createdAt?.toDate?.()?.toISOString() || null,
        changeCount: Number(details.changeCount || data.metadata?.changeCount || 0) || 0,
        range: typeof details.range === 'string' ? details.range : null,
      };
    });
    sendJson(res, 200, { ok: true, events, limited: snapshot.size === limit });
  } catch (error) {
    recordWorkspaceDiagnostic('audit_events', error);
    const safe = workspaceSafeError(error, { writeMayHaveStarted: false });
    console.error('Workspace audit event listing failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
  }
}

function parseWorkspaceReportPeriod(body) {
  const startDate = String(body.startDate || '').slice(0, 10);
  const endDate = String(body.endDate || '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(endDate) || startDate > endDate) {
    const error = new Error('فترة التقرير غير صحيحة.');
    error.code = 'validation';
    throw error;
  }
  return { startDate, endDate };
}

async function handleWorkspaceHrReport(req, res) {
  let reservation;
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) throw new Error('Unauthorized');
    if (!canViewWorkspaceHrReports(actor)) {
      const error = new Error('لا تملك صلاحية تقارير الموارد البشرية.');
      error.code = 'forbidden';
      throw error;
    }
    const body = await readJsonBody(req);
    const reportType = String(body.reportType || '').trim();
    if (!['attendance', 'requests', 'deductions'].includes(reportType)) {
      const error = new Error('نوع التقرير غير مدعوم.');
      error.code = 'validation';
      throw error;
    }
    const period = parseWorkspaceReportPeriod(body);
    const db = admin.firestore();
    const key = reportKey({ type: `hr_${reportType}`, scopeId: 'company', ...period });
    reservation = await reserveWorkspaceReport({ db, key, actorId: actor.uid });
    if (reservation.kind === 'replay') {
      sendJson(res, 200, { ok: true, ...reservation.result, replayed: true });
      return;
    }
    if (reservation.kind === 'running') {
      sendJson(res, 202, { ok: true, state: 'generating', message: 'جارٍ إعداد التقرير. أعد التحقق بعد لحظات.' });
      return;
    }
    // These are authoritative business records. A permission's requestDate is
    // its execution date, so later approval cannot move it to another period.
    const [attendanceSnap, permissionsSnap, leavesSnap] = await Promise.all([
      db.collection('attendance').where('date', '>=', period.startDate)
        .where('date', '<=', period.endDate).limit(5000).get(),
      db.collection('permissions').where('requestDate', '>=', period.startDate)
        .where('requestDate', '<=', period.endDate).limit(5000).get(),
      db.collection('leaves').where('status', '==', 'approved').limit(5000).get(),
    ]);
    const userIds = new Set([
      ...attendanceSnap.docs.map((doc) => String(doc.data().userId || '')),
      ...permissionsSnap.docs.map((doc) => String(doc.data().userId || '')),
      ...leavesSnap.docs.map((doc) => String(doc.data().userId || '')),
    ].filter(Boolean));
    const userDocs = await Promise.all([...userIds].map((id) => db.collection('users').doc(id).get()));
    const reportData = buildHrOperationalRows({
      reportType,
      period,
      attendance: attendanceSnap.docs.map((doc) => doc.data()),
      permissions: permissionsSnap.docs.map((doc) => doc.data()),
      leaves: leavesSnap.docs.map((doc) => doc.data()),
      users: userDocs.filter((doc) => doc.exists).map((doc) => ({ id: doc.id, ...doc.data() })),
    });
    const labels = { attendance: 'الحضور', requests: 'الطلبات', deductions: 'الخصومات' };
    const reportName = `ZaWolf - تقرير ${labels[reportType]}`;
    const report = await getGoogleSheetsIntegration().writeWorkspaceAuditReport(
      reportData.headers,
      reportData.rows,
      { reportName, tabTitle: `${period.startDate} إلى ${period.endDate}` },
    );
    // Keep every period independently discoverable and replayable.  The
    // report-run reservation guarantees a duplicate request returns this same
    // resource rather than creating another spreadsheet.
    const resourceId = reportRunId(key);
    await db.collection('workspaceResources').doc(resourceId).set({
      name: reportName, type: 'sheet', department: 'الموارد البشرية',
      description: `تقرير ${labels[reportType]} للفترة ${period.startDate} إلى ${period.endDate}`,
      hasExternalId: true, schemaProfileId: '', sheetTab: report.tabTitle,
      managerIds: [], isActive: true, syncStatus: 'connected',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection('workspaceResourceSecrets').doc(resourceId).set({
      externalId: report.spreadsheetId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const response = {
      rowCount: report.rowCount,
      resource: { id: resourceId, name: reportName, type: 'sheet', sheetTab: report.tabTitle },
      period, reportType,
    };
    await appendWorkspaceAudit({
      db, actorId: actor.uid, resourceId, action: 'report_generate',
      details: { reportKey: key, changeCount: report.rowCount },
    });
    await completeWorkspaceReport({ reservation, result: response });
    sendJson(res, 200, { ok: true, ...response });
  } catch (error) {
    recordWorkspaceDiagnostic('hr_report', error);
    await failWorkspaceReport({ reservation }).catch(() => {});
    const safe = workspaceSafeError(error, { writeMayHaveStarted: true });
    console.error('Workspace HR report failed:', error.message || error);
    sendJson(res, safe.statusCode, { ok: false, error: safe.error, retry: safe.retry });
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

async function conversationForActor(db, actor, conversationId) {
  const id = safeConversationId(conversationId);
  if (!id) return null;
  const document = await db.collection('conversations').doc(id).get();
  if (!document.exists) return null;
  const data = document.data() || {};
  const authorized = data.kind === 'department'
    ? data.state !== 'closed' && canAccessDepartment(actor, data.departmentName)
    : isConversationMember(data, actor.uid);
  if (!authorized) {
    return null;
  }
  return { id, ref: document.ref, data };
}

function opaqueConversationId(prefix, ...parts) {
  const digest = crypto.createHash('sha256').update(parts.join('\u001f')).digest('hex');
  return `${prefix}:${digest.slice(0, 48)}`;
}

async function recordConversationAudit(db, {
  actorId, conversationId, operationId, action, resourceId = null,
}) {
  await db.collection('conversationAudit')
    .doc(`${conversationId}:${operationId}:${action}`)
    .set({
      actorId,
      conversationId,
      operationId,
      action,
      resourceId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}

async function ensureConversationAttachmentsFolder(db) {
  const configured = String(process.env.GOOGLE_CONVERSATIONS_FOLDER_ID || '').trim();
  if (configured) return configured;
  const configRef = db.collection('integrationConfig').doc('conversationAttachmentsDrive');
  const current = await configRef.get();
  const stored = String(current.data()?.folderId || '').trim();
  if (stored) return stored;
  const rootFolderId = String(process.env.GOOGLE_WORKSPACE_ROOT_FOLDER_ID || '').trim();
  if (!rootFolderId) return '';
  const connector = getGoogleSheetsIntegration();
  const conversationConfig = await db.collection('integrationConfig')
    .doc('conversationAttachmentsDrive').get();
  const existingSharedFolderId = String(
    conversationConfig.data()?.parentFolderId || '',
  ).trim();
  const shared = existingSharedFolderId
    ? { id: existingSharedFolderId }
    : await connector.createWorkspaceDriveFolder({
      parentFolderId: rootFolderId,
      name: '05_ملفات_مشتركة',
      useDriveUploadOAuth: true,
    });
  const attachments = await connector.createWorkspaceDriveFolder({
    parentFolderId: shared.id,
    name: 'مرفقات_المحادثات',
    useDriveUploadOAuth: true,
  });
  await configRef.set({
    folderId: attachments.id,
    parentFolderId: shared.id,
    provider: 'google_workspace',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return String(attachments.id || '');
}

// Request files are deliberately separated from chat files.  The app only
// receives an opaque attachment id; the Drive id stays server-side in the
// workspaceResourceSecrets collection.
async function ensureOperationalRequestAttachmentsFolder(db) {
  const configured = String(process.env.GOOGLE_OPERATIONAL_REQUESTS_FOLDER_ID || '').trim();
  if (configured) return configured;
  const configRef = db.collection('integrationConfig').doc('operationalRequestAttachmentsDrive');
  const current = await configRef.get();
  const stored = String(current.data()?.folderId || '').trim();
  if (stored) return stored;
  const rootFolderId = String(process.env.GOOGLE_WORKSPACE_ROOT_FOLDER_ID || '').trim();
  if (!rootFolderId) return '';
  const connector = getGoogleSheetsIntegration();
  const shared = await connector.createWorkspaceDriveFolder({
    parentFolderId: rootFolderId,
    name: '05_ملفات_مشتركة',
    useDriveUploadOAuth: true,
  });
  const attachments = await connector.createWorkspaceDriveFolder({
    parentFolderId: shared.id,
    name: 'مرفقات_الطلبات',
    useDriveUploadOAuth: true,
  });
  await configRef.set({
    folderId: attachments.id,
    parentFolderId: shared.id,
    provider: 'google_workspace',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return String(attachments.id || '');
}

async function uploadOperationalRequestAttachment({ db, actor, resourceId, payload }) {
  const attachmentRef = db.collection('companyOsRequestAttachments').doc(resourceId);
  const existing = await attachmentRef.get();
  if (existing.exists && existing.data()?.status === 'uploaded' &&
      existing.data()?.uploaderUid === actor.uid) {
    const data = existing.data();
    return {
      id: resourceId,
      displayName: data.displayName,
      contentType: data.contentType,
      sizeBytes: Number(data.sizeBytes || 0),
    };
  }
  const folderId = await ensureOperationalRequestAttachmentsFolder(db);
  if (!folderId) {
    const error = new Error('Workspace request attachments unavailable');
    error.code = 'temporary_unavailable';
    throw error;
  }
  const sizeBytes = Buffer.from(payload.contentsBase64, 'base64').length;
  await attachmentRef.set({
    uploaderUid: actor.uid,
    displayName: payload.displayName,
    contentType: payload.contentType,
    sizeBytes,
    status: 'pending',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  const uploaded = await uploadGovernedAttachment({
    connector: getGoogleSheetsIntegration(),
    parentFolderId: folderId,
    useDriveUploadOAuth: true,
    payload: {
      name: payload.displayName,
      mimeType: payload.contentType,
      contentsBase64: payload.contentsBase64,
    },
  });
  const externalId = String(uploaded?.id || '').trim();
  if (!externalId) {
    const error = new Error('Request attachment upload failed');
    error.code = 'temporary_unavailable';
    throw error;
  }
  const batch = db.batch();
  batch.set(attachmentRef, {
    uploaderUid: actor.uid,
    displayName: payload.displayName,
    contentType: payload.contentType,
    sizeBytes,
    status: 'uploaded',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(db.collection('workspaceResourceSecrets').doc(resourceId), {
    externalId,
    parentExternalId: folderId,
    provider: 'google_workspace',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await batch.commit();
  return {
    id: resourceId,
    displayName: payload.displayName,
    contentType: payload.contentType,
    sizeBytes,
  };
}

async function handleConversationRequest(req, res, url) {
  if (url.pathname.startsWith('/conversations/v2/')) {
    const actor = await authorizeWorkspaceRequest(req);
    const db = admin.firestore();
    return require('./conversations/router').handleRichConversationRequest({
      req, res, url, actor, db, admin, readJsonBody, sendJson,
      enabled: Boolean(actor && isPhase007FlagEnabled('conversations_rich_chat_v1', phase007FlagConfig, actor.uid)),
      getMediaProvider: () => getGoogleSheetsIntegration().createConversationMediaProvider(),
      ensureFolder: () => ensureConversationAttachmentsFolder(db),
      triggerPushDispatch: () => schedulePushDispatch('conversation_message', 0),
    });
  }
  const actor = await authorizeWorkspaceRequest(req);
  if (!actor) {
    sendJson(res, 401, { ok: false, code: 'session_expired' });
    return;
  }
  const db = admin.firestore();
  const parts = url.pathname.split('/').filter(Boolean).map(decodeURIComponent);
  try {
    // A shared channel for the management team. HR/admin are members too so
    // they can moderate it, but ordinary employees cannot enter it.
    if (req.method === 'GET' && parts.length === 2 && parts[1] === 'manager-channel') {
      const managementRoles = new Set(['manager', 'team_leader']);
      if (!managementRoles.has(actor.role) && !isHrOrAdmin(actor) && !isWorkspaceController(actor)) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const users = await db.collection('users').where('isActive', '==', true).limit(750).get();
      const memberUserIds = users.docs.filter((doc) => {
        const user = doc.data() || {};
        const role = String(user.role || '').toLowerCase();
        return managementRoles.has(role) || ['hr', 'hr_admin', 'hr_manager', 'admin', 'super_admin'].includes(role);
      }).map((doc) => doc.id).sort();
      const conversationId = opaqueConversationId('manager-channel', 'v1');
      await db.collection('conversations').doc(conversationId).set({
        kind: 'manager_channel', purposeAr: 'قناة المديرين', state: 'active',
        memberUserIds, createdBy: 'system',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      sendJson(res, 200, { ok: true, conversationId, name: 'قناة المديرين' });
      return;
    }

    if (req.method === 'GET' && parts.length === 2 && parts[1] === 'channels') {
      const snapshot = await db.collection('conversations')
        .where('memberUserIds', 'array-contains', actor.uid).limit(100).get();
      const channels = snapshot.docs.map((doc) => {
        const data = doc.data() || {};
        return { id: doc.id, name: String(data.purposeAr || 'قناة محادثة'), kind: String(data.kind || 'custom') };
      }).filter((channel) => channel.id && channel.name).sort((a, b) => a.name.localeCompare(b.name, 'ar'));
      sendJson(res, 200, { ok: true, channels });
      return;
    }

    if (req.method === 'POST' && parts.length === 2 && parts[1] === 'channels') {
      if (!(isHrOrAdmin(actor) || isWorkspaceController(actor))) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const payload = await readJsonBody(req, 16 * 1024);
      const name = String(payload.name || '').trim();
      const operationId = safeConversationId(payload.operationId);
      const members = [...new Set((Array.isArray(payload.memberUserIds) ? payload.memberUserIds : [])
        .map(safeConversationId).filter(Boolean).concat(actor.uid))].sort();
      if (!operationId || !name || name.length > 120 || members.length < 2 || members.length > 100) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const conversationId = opaqueConversationId('hr-channel', actor.uid, operationId);
      await db.collection('conversations').doc(conversationId).set({
        kind: 'custom', purposeAr: name, state: 'active', memberUserIds: members,
        createdBy: actor.uid, createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      await recordConversationAudit(db, { actorId: actor.uid, conversationId, operationId, action: 'channel_create' });
      sendJson(res, 201, { ok: true, conversationId, name });
      return;
    }

    if (req.method === 'PUT' && parts.length === 3 && parts[1] === 'channels') {
      if (!(isHrOrAdmin(actor) || isWorkspaceController(actor))) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const conversationId = safeConversationId(parts[2]);
      const payload = await readJsonBody(req, 16 * 1024);
      const members = [...new Set((Array.isArray(payload.memberUserIds) ? payload.memberUserIds : [])
        .map(safeConversationId).filter(Boolean).concat(actor.uid))].sort();
      if (!conversationId || members.length < 2 || members.length > 100) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const ref = db.collection('conversations').doc(conversationId);
      const existing = await ref.get();
      if (!existing.exists || existing.data()?.kind !== 'custom') {
        sendJson(res, 404, { ok: false, code: 'not_found' });
        return;
      }
      await ref.update({ memberUserIds: members, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      await recordConversationAudit(db, { actorId: actor.uid, conversationId,
        operationId: `channel_members:${Date.now()}`, action: 'channel_members_update' });
      sendJson(res, 200, { ok: true, conversationId, memberCount: members.length });
      return;
    }

    if (req.method === 'POST' && parts.length === 3 &&
        parts[1] === 'attachments' && parts[2] === 'bootstrap') {
      if (!(isHrOrAdmin(actor) || isWorkspaceController(actor))) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const folderId = await ensureConversationAttachmentsFolder(db);
      if (!folderId) {
        sendJson(res, 503, { ok: false, code: 'workspace_root_not_configured' });
        return;
      }
      sendJson(res, 200, { ok: true, code: 'ready', folderId });
      return;
    }

    if (req.method === 'GET' && parts.length === 2 && parts[1] === 'departments') {
      const canCrossDepartments = isHrOrAdmin(actor) || isWorkspaceController(actor);
      if (!canCrossDepartments) {
        if (!canAccessDepartment(actor, actor.department)) {
          sendJson(res, 403, { ok: false, code: 'department_not_assigned' });
          return;
        }
        sendJson(res, 200, {
          ok: true,
          departments: [normalizeDepartmentName(actor.department)],
        });
        return;
      }
      const users = await db.collection('users').where('isActive', '==', true).limit(750).get();
      const departments = [...new Set(users.docs.map((doc) => {
        const data = doc.data() || {};
        return normalizeDepartmentName(
          data.department || data.departmentName || data.departmentId || data.dept,
        );
      }).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'ar'));
      sendJson(res, 200, { ok: true, departments });
      return;
    }

    if ((req.method === 'GET' || req.method === 'POST') &&
        parts.length === 3 && parts[1] === 'department') {
      const requestedDepartment = normalizeDepartmentName(parts[2]);
      if (!requestedDepartment || !canAccessDepartment(actor, requestedDepartment)) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const conversationId = opaqueConversationId(
        'department', departmentKey(requestedDepartment),
      );
      const ref = db.collection('conversations').doc(conversationId);
      const existing = await ref.get();
      if (!existing.exists) {
        await ref.create({
          kind: 'department',
          departmentKey: departmentKey(requestedDepartment),
          departmentName: requestedDepartment,
          purposeAr: `قناة قسم ${requestedDepartment}`,
          state: 'active',
          createdBy: actor.uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await recordConversationAudit(db, {
          actorId: actor.uid,
          conversationId,
          operationId: `department:${departmentKey(requestedDepartment)}`,
          action: 'department_conversation_provisioned',
        });
      }
      sendJson(res, 200, {
        ok: true,
        code: existing.exists ? 'found' : 'created',
        conversationId,
        departmentName: requestedDepartment,
      });
      return;
    }

    if (req.method === 'POST' && parts.length === 1) {
      const payload = await readJsonBody(req, 8 * 1024);
      const operationId = safeConversationId(payload.operationId);
      const memberUserIds = normalizeMemberIds(actor.uid, payload.memberUserIds);
      const purposeAr = String(payload.purposeAr || '').trim();
      if (!operationId || !memberUserIds || !purposeAr || purposeAr.length > 240) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const conversationId = opaqueConversationId('conversation', actor.uid, operationId);
      const ref = db.collection('conversations').doc(conversationId);
      const existing = await ref.get();
      if (existing.exists) {
        sendJson(res, 200, { ok: true, code: 'created', conversationId });
        return;
      }
      const memberDocs = await db.getAll(
        ...memberUserIds.map((id) => db.collection('users').doc(id)),
      );
      const memberUsers = memberDocs.map((doc) => ({
        uid: doc.id,
        ...(doc.data() || {}),
      }));
      const actorUser = memberUsers.find((user) => user.uid === actor.uid);
      if (memberDocs.some((doc) => !doc.exists) ||
          !canStartConversation({ actor, actorUser, memberUsers })) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      await ref.create({
        memberUserIds,
        purposeAr,
        state: 'active',
        createdBy: actor.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await recordConversationAudit(db, {
        actorId: actor.uid, conversationId, operationId, action: 'conversation_create',
      });
      sendJson(res, 201, { ok: true, code: 'created', conversationId });
      return;
    }

    const conversationId = parts[1];
    const conversation = await conversationForActor(db, actor, conversationId);
    if (!conversation) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }

    if (req.method === 'GET' && parts.length === 3 && parts[2] === 'messages') {
      const limit = Math.min(100, Math.max(1, Number(url.searchParams.get('limit')) || 100));
      const snapshot = await conversation.ref.collection('messages')
        .orderBy('sentAt', 'desc')
        .limit(limit)
        .get();
      const messages = snapshot.docs.map((doc) => {
        const data = doc.data() || {};
        return {
          id: doc.id,
          conversationId: conversation.id,
          senderUserId: String(data.senderUserId || ''),
          senderDisplayName: String(data.senderDisplayName || ''),
          body: String(data.body || ''),
          attachmentResourceIds: Array.isArray(data.attachmentResourceIds)
            ? data.attachmentResourceIds.map((value) => String(value)) : [],
          state: String(data.state || 'sent'),
          sentAt: data.sentAt?.toDate?.().toISOString() || '',
        };
      });
      sendJson(res, 200, { ok: true, messages });
      return;
    }

    if (req.method === 'POST' && parts.length === 3 && parts[2] === 'messages') {
      const payload = normalizeMessageInput(await readJsonBody(req, 16 * 1024));
      if (!payload) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      await require('./conversations/messages').sendMessage({
        db, admin, actor, channelId: conversation.id, payload, legacy: true,
      });
      sendJson(res, 200, {
        ok: true, code: 'sent', messageId: payload.operationId,
      });
      return;
    }

    if (req.method === 'POST' && parts.length === 3 && parts[2] === 'attachments') {
      const payload = normalizeAttachmentInput(
        await readJsonBody(req, 15 * 1024 * 1024),
      );
      const folderId = await ensureConversationAttachmentsFolder(db);
      if (!payload) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      if (!folderId) {
        sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
        return;
      }
      const resourceId = opaqueConversationId(
        'chat', conversation.id, payload.operationId,
      );
      const attachmentRef = db.collection('conversationAttachments').doc(resourceId);
      const existing = await attachmentRef.get();
      if (existing.exists && existing.data()?.status === 'uploaded') {
        sendJson(res, 200, { ok: true, code: 'uploaded', resourceId });
        return;
      }
      await attachmentRef.set({
        conversationId: conversation.id,
        uploaderUserId: actor.uid,
        name: payload.name,
        mimeType: payload.mimeType,
        status: 'pending',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      const uploaded = await uploadGovernedAttachment({
        connector: getGoogleSheetsIntegration(),
        parentFolderId: folderId,
        useDriveUploadOAuth: true,
        payload,
      });
      const externalId = String(uploaded?.id || '').trim();
      if (!externalId) throw new Error('attachment_upload_failed');
      const batch = db.batch();
      batch.set(attachmentRef, {
        conversationId: conversation.id,
        uploaderUserId: actor.uid,
        name: payload.name,
        mimeType: payload.mimeType,
        sizeBytes: Buffer.from(payload.contentsBase64, 'base64').length,
        status: 'uploaded',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      batch.set(db.collection('workspaceResourceSecrets').doc(resourceId), {
        externalId,
        parentExternalId: folderId,
        provider: 'google_workspace',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      await batch.commit();
      await recordConversationAudit(db, {
        actorId: actor.uid, conversationId: conversation.id,
        operationId: payload.operationId, action: 'attachment_upload', resourceId,
      });
      sendJson(res, 200, { ok: true, code: 'uploaded', resourceId });
      return;
    }

    if (req.method === 'GET' && parts.length === 5 &&
        parts[2] === 'attachments' && parts[4] === 'download') {
      const resourceId = safeConversationId(parts[3]);
      if (!resourceId) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const [attachment, secret] = await Promise.all([
        db.collection('conversationAttachments').doc(resourceId).get(),
        db.collection('workspaceResourceSecrets').doc(resourceId).get(),
      ]);
      if (!attachment.exists || attachment.data()?.conversationId !== conversation.id ||
          attachment.data()?.status !== 'uploaded' || !secret.exists) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const payload = await downloadGovernedAttachment({
        connector: getGoogleSheetsIntegration(),
        parentFolderId: String(secret.data()?.parentExternalId || ''),
        externalFileId: String(secret.data()?.externalId || ''),
        useDriveUploadOAuth: true,
      });
      await recordConversationAudit(db, {
        actorId: actor.uid, conversationId: conversation.id,
        operationId: `download:${resourceId}`, action: 'attachment_download', resourceId,
      });
      sendBinary(res, payload);
      return;
    }

    sendJson(res, 404, { ok: false, code: 'not_found' });
  } catch (error) {
    recordWorkspaceDiagnostic('conversation_operation', error);
    // A service account can read a folder shared from a personal Drive but
    // cannot own uploaded files there because it has no Drive storage quota.
    // Keep the provider response private, while returning an actionable code
    // that the client can explain without exposing a raw Node/Google error.
    const providerStatus = Number(error?.response?.status || error?.status || 0);
    if (providerStatus === 403) {
      sendJson(res, 503, { ok: false, code: 'drive_upload_not_ready' });
      return;
    }
    sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
  }
}

const REQUEST_ARCHIVE_COLLECTIONS = new Set([
  'administrativeRequests',
  'leaves',
  'permissions',
  'advances',
  'attendanceCorrectionRequests',
]);
// The notification action also supports approval-chain custom requests. They
// are not archivable through this legacy management endpoint.
const REQUEST_NOTIFICATION_COLLECTIONS = new Set([
  ...REQUEST_ARCHIVE_COLLECTIONS,
  'administrativeRequests',
  'customRequests',
]);

// Management removal is deliberately an archive, not a destructive delete:
// request, payroll and approval evidence remain recoverable for audit.
async function handleRequestManagementArchive(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!(isHrOrAdmin(actor) || isWorkspaceController(actor))) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    const payload = await readJsonBody(req, 8 * 1024);
    const collection = String(payload.collection || '');
    const requestId = String(payload.requestId || '');
    if (!REQUEST_ARCHIVE_COLLECTIONS.has(collection) ||
        !/^[A-Za-z0-9_-]{1,256}$/.test(requestId)) {
      sendJson(res, 400, { ok: false, code: 'validation_failed' });
      return;
    }

    const db = admin.firestore();
    const requestRef = db.collection(collection).doc(requestId);
    await db.runTransaction(async (transaction) => {
      const request = await transaction.get(requestRef);
      if (!request.exists) {
        const error = new Error('not_found');
        error.code = 'not_found';
        throw error;
      }
      const data = request.data() || {};
      transaction.set(requestRef, {
        managementArchived: true,
        managementArchivedAt: admin.firestore.FieldValue.serverTimestamp(),
        managementArchivedBy: actor.uid,
        managementArchiveReason: 'removed_from_active_management',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(
        db.collection('requestManagementArchives').doc(`${collection}_${requestId}`),
        {
          collection,
          requestId,
          actorId: actor.uid,
          requestUserId: String(data.userId || ''),
          requestEmployeeId: String(data.employeeId || ''),
          archivedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: 'removed_from_active_management',
        },
        { merge: true },
      );
    });
    await appendWorkspaceAudit({
      db,
      actorId: actor.uid,
      resourceId: `request:${collection}/${requestId}`,
      action: 'request_management_archived',
      details: { collection, requestId },
    });
    sendJson(res, 200, { ok: true, code: 'archived' });
  } catch (error) {
    recordWorkspaceDiagnostic('request_management_archive', error);
    if (error?.code === 'not_found') {
      sendJson(res, 404, { ok: false, code: 'not_found' });
      return;
    }
    sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
  }
}

async function requestEmployeeDocument(db, requestData) {
  const directUserId = employeeUserIdFromRequest(requestData);
  if (directUserId) {
    const direct = await db.collection('users').doc(directUserId).get();
    if (direct.exists) return direct;
  }
  const employeeId = String(requestData.employeeId || requestData.employeeCode || '').trim();
  if (!employeeId) return null;
  const match = await db.collection('users')
    .where('employeeId', '==', employeeId)
    .limit(1)
    .get();
  return match.empty ? null : match.docs[0];
}

async function handleRequestManagementNotification(req, res) {
  try {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!(isHrOrAdmin(actor) || isWorkspaceController(actor))) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    const rawBody = await readJsonBody(req, 12 * 1024);
    if (rawBody && !rawBody.operationId && req.headers['x-operation-id']) {
      rawBody.operationId = req.headers['x-operation-id'];
    }
    const input = normalizeRequestNotificationInput(rawBody);
    if (!input || !REQUEST_NOTIFICATION_COLLECTIONS.has(input.collection)) {
      sendJson(res, 400, { ok: false, code: 'validation_failed' });
      return;
    }

    const db = admin.firestore();
    const requestDoc = await db.collection(input.collection).doc(input.requestId).get();
    if (!requestDoc.exists) {
      sendJson(res, 404, { ok: false, code: 'not_found' });
      return;
    }
    const requestData = requestDoc.data() || {};
    const employeeDoc = await requestEmployeeDocument(db, requestData);
    if (!employeeDoc) {
      sendJson(res, 409, { ok: false, code: 'employee_not_linked' });
      return;
    }
    const employee = employeeDoc.data() || {};
    const requestedRecipientIds = recipientUserIds({
      input,
      request: requestData,
      employee: { ...employee, uid: employeeDoc.id },
    });
    if (!requestedRecipientIds.length) {
      sendJson(res, 409, { ok: false, code: 'manager_not_assigned' });
      return;
    }
    const resolvedRecipientUserIds = [];
    for (const id of requestedRecipientIds) {
      if (!id) continue;
      const normalizedId = String(id).trim();
      const docDirect = await db.collection('users').doc(normalizedId).get();
      if (docDirect.exists) {
        resolvedRecipientUserIds.push(docDirect.id);
        continue;
      }
      let empDoc = await db.collection('users').where('employeeId', '==', normalizedId).limit(1).get();
      if (empDoc.empty) {
        empDoc = await db.collection('users').where('employeeCode', '==', normalizedId).limit(1).get();
      }
      if (!empDoc.empty) {
        resolvedRecipientUserIds.push(empDoc.docs[0].id);
        continue;
      }
      resolvedRecipientUserIds.push(normalizedId);
    }
    const uniqueRecipientIds = [...new Set(resolvedRecipientUserIds)];
    if (!uniqueRecipientIds.length) {
      sendJson(res, 409, { ok: false, code: 'manager_not_assigned' });
      return;
    }
    const recipientDocs = await db.getAll(
      ...uniqueRecipientIds.map((id) => db.collection('users').doc(id)),
    );
    const recipients = recipientDocs.filter((doc) => doc.exists);
    if (!recipients.length) {
      sendJson(res, 409, { ok: false, code: 'recipient_not_found' });
      return;
    }

    let createdCount = 0;
    const employeeName = requestEmployeeName(requestData, employee);
    for (const recipient of recipients) {
      const notification = buildRequestNotification({
        input,
        recipientUserId: recipient.id,
        employeeName,
      });
      const notificationRef = db.collection('notifications')
        .doc(recipient.id)
        .collection('items')
        .doc(notification.notificationId);
      const created = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(notificationRef);
        if (existing.exists) return false;
        transaction.create(notificationRef, {
          ...notification,
          createdBy: actor.uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(recipient.ref, {
          unreadNotifications: admin.firestore.FieldValue.increment(1),
        }, { merge: true });
        return true;
      });
      if (created) createdCount += 1;
    }

    try {
      await appendWorkspaceAudit({
        db,
        actorId: actor.uid,
        resourceId: `request:${input.collection}/${input.requestId}`,
        action: input.target === 'manager'
          ? 'request_manager_reminder_sent'
          : 'request_employee_edit_notice_sent',
        details: {
          collection: input.collection,
          requestId: input.requestId,
          recipientCount: recipients.length,
          target: input.target,
        },
      });
    } catch (auditError) {
      recordWorkspaceDiagnostic('request_management_notification_audit', auditError);
    }
    // A Firestore listener normally wakes the dispatcher. Hostinger can run
    // more than one worker, though, and this worker may be in listener
    // standby. Wake the durable OneSignal queue directly after the transaction
    // commits so a manager receives an OS notification while the app is
    // backgrounded or terminated instead of relying on its in-app listener.
    schedulePushDispatch('request_management_notification', 0);
    sendJson(res, 200, {
      ok: true,
      code: createdCount ? 'notification_sent' : 'already_sent',
      recipientCount: recipients.length,
    });
  } catch (error) {
    recordWorkspaceDiagnostic('request_management_notification', error);
    sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
  }
}

async function handleOperationalVisibilityRequest(req, res, url) {
  const actor = await authorizeWorkspaceRequest(req);
  if (!actor) {
    sendJson(res, 401, { ok: false, code: 'session_expired' });
    return;
  }
  const db = admin.firestore();
  try {
    const visibilityMatch = url.pathname.match(
      /^\/operations\/visibility\/([A-Za-z0-9_-]{1,128})$/,
    );
    if (visibilityMatch && req.method === 'POST') {
      if (!canManageOperationalVisibility(actor)) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const employeeUserId = safeOperationalUserId(visibilityMatch[1]);
      const body = await readJsonBody(req, 8 * 1024);
      const operationId = safeConversationId(
        body.operationId || req.headers['x-operation-id'],
      );
      const reasonAr = String(body.reasonAr || '').trim();
      const hidden = body.hidden === true;
      if (!employeeUserId || !operationId || reasonAr.length < 3 || reasonAr.length > 300) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const targetRef = db.collection('users').doc(employeeUserId);
      const settingRef = db.collection('operationalVisibility').doc(employeeUserId);
      const operationRef = db.collection('operationalOperations').doc(operationId);
      let version = 1;
      let replayed = false;
      await db.runTransaction(async (transaction) => {
        const [target, current, operation] = await Promise.all([
          transaction.get(targetRef),
          transaction.get(settingRef),
          transaction.get(operationRef),
        ]);
        if (operation.exists) {
          replayed = true;
          version = Number(operation.data()?.version || 1);
          return;
        }
        if (!target.exists || target.data()?.isActive !== true) {
          const error = new Error('target_not_found');
          error.code = 'target_not_found';
          throw error;
        }
        version = Number(current.data()?.version || 0) + 1;
        transaction.set(settingRef, {
          employeeUserId,
          hiddenFromAttendance: hidden,
          reasonAr,
          version,
          updatedByUserId: actor.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(operationRef, {
          action: hidden ? 'attendance_visibility_hidden' : 'attendance_visibility_restored',
          actorId: actor.uid,
          targetUserId: employeeUserId,
          version,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(db.collection('operationalAudit').doc(operationId), {
          action: hidden ? 'attendance_visibility_hidden' : 'attendance_visibility_restored',
          actorId: actor.uid,
          targetUserId: employeeUserId,
          reasonAr,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      sendJson(res, 200, {
        ok: true,
        code: replayed ? 'replayed' : hidden ? 'hidden' : 'restored',
        employeeUserId,
        hidden,
        version,
      });
      return;
    }

    if (url.pathname === '/operations/employee-timeline' && req.method === 'GET') {
      const employeeUserId = safeOperationalUserId(
        url.searchParams.get('employeeUserId'),
      );
      const period = normalizeOperationalPeriod(
        url.searchParams.get('from'),
        url.searchParams.get('to'),
      );
      const pageSize = safeOperationalPageSize(url.searchParams.get('limit'));
      const cursor = String(url.searchParams.get('cursor') || '').trim();
      if (!employeeUserId || !period || cursor.length > 300) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const targetDocument = await db.collection('users').doc(employeeUserId).get();
      const targetData = targetDocument.data() || {};
      const target = { uid: employeeUserId, ...targetData };
      if (!targetDocument.exists || !canInspectEmployee(actor, target)) {
        sendJson(res, 403, { ok: false, code: 'access_denied' });
        return;
      }
      const sources = [
        { collection: 'attendance', kind: 'attendance', identity: 'userId' },
        { collection: 'leaves', kind: 'leave', identity: 'userId' },
        { collection: 'permissions', kind: 'permission', identity: 'userId' },
        { collection: 'attendanceCorrectionRequests', kind: 'correction', identity: 'userId' },
        { collection: 'administrativeRequests', kind: 'request', identity: 'userId' },
        { collection: 'advances', kind: 'advance', identity: 'userId' },
        { collection: 'manual_deductions', kind: 'deduction', identity: 'userId' },
        { collection: 'complaints', kind: 'complaint', identity: 'userId' },
        { collection: 'resignations', kind: 'resignation', identity: 'userId' },
        // Account-deletion records store the affected Firebase uid in
        // employeeId, unlike ordinary employee requests.
        { collection: 'employeeDeletionRequests', kind: 'account_deletion', identity: 'employeeId' },
      ];
      // Every source read is actor-scoped and capped. Different legacy source
      // schemas use different effective-date fields, so date normalization is
      // performed after this bounded identity query.
      const snapshots = await Promise.all(sources.map((source) =>
        db.collection(source.collection)
          .where(source.identity, '==', employeeUserId)
          .limit(Math.min(200, pageSize * 2))
          .get()));
      const rows = snapshots.flatMap((snapshot, index) => snapshot.docs.map((doc) => ({
        id: doc.id,
        source: sources[index].collection,
        kind: sources[index].kind,
        data: doc.data(),
      })));
      const page = normalizeTimelineRows(rows, period, cursor || null, pageSize);
      sendJson(res, 200, { ok: true, ...page });
      return;
    }

    sendJson(res, 405, { ok: false, code: 'method_not_allowed' });
  } catch (error) {
    recordWorkspaceDiagnostic('operational_visibility', error);
    const status = error?.code === 'target_not_found' ? 404 : 503;
    sendJson(res, status, {
      ok: false,
      code: status === 404 ? 'target_not_found' : 'temporarily_unavailable',
    });
  }
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
    const attendancePermissionReconciliation =
      await reconcileFinalizedPermissions(admin.firestore());
    const automaticAttendance = await processAutomaticAttendance();
    const push = await dispatchNotifications();
    return {
      managerLeaveBypasses,
      attendancePermissionReconciliation,
      automaticAttendance,
      ...push,
    };
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
    const attendancePermissionReconciliation =
      await reconcileFinalizedPermissions(admin.firestore());
    const automaticAttendance = await processAutomaticAttendance();
    const reminders = await queueAttendanceReminders();
    const push = await dispatchNotifications();
    return {
      managerLeaveBypasses,
      attendancePermissionReconciliation,
      automaticAttendance,
      reminders,
      push,
    };
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
    let attendancePermissionReconciliation;
    try {
      managerLeaveBypasses =
        await processManagerLeavePermissionBypasses();
      attendancePermissionReconciliation =
        await reconcileFinalizedPermissions(admin.firestore());
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
    return {
      managerLeaveBypasses,
      attendancePermissionReconciliation,
      automaticAttendance,
      reminders,
    };
  });

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
    url.pathname === '/attendance/checkout-policy' ||
    url.pathname === '/attendance/security-review' ||
    url.pathname.startsWith('/attendance/locations/');
  const isConversationRoute =
    url.pathname.startsWith('/conversations/v2/') ||
    url.pathname === '/conversations' ||
    url.pathname === '/conversations/departments' ||
    url.pathname === '/conversations/channels' ||
    url.pathname === '/conversations/manager-channel' ||
    /^\/conversations\/channels\/[A-Za-z0-9_.:%-]{1,256}$/.test(url.pathname) ||
    url.pathname === '/conversations/attachments/bootstrap' ||
    /^\/conversations\/department\/[^/]{1,256}$/.test(url.pathname) ||
    /^\/conversations\/[A-Za-z0-9_.:%-]{1,256}\/(?:messages|attachments)(?:\/[A-Za-z0-9_.:%-]{1,256}\/download)?$/.test(url.pathname);
  const isCompanyOsRoute = url.pathname.startsWith('/company-os/');
  const isDeveloperApiRoute = url.pathname.startsWith('/developer-api/v1/');
  // HR operational routes are consumed by the Flutter web application too.
  // Keep them in the same CORS boundary as the established operations routes;
  // otherwise browsers block authenticated preflight requests before the
  // endpoint has a chance to return its useful Arabic error response.
  const isHrOperationsRoute = url.pathname.startsWith('/operations/');
  const isPhase007OperationRoute = url.pathname.startsWith('/operations/');

  if ((isGoogleWorkspaceRoute || isAttendanceGatewayRoute || isPhase007OperationRoute || isConversationRoute || isCompanyOsRoute || isHrOperationsRoute) && req.method === 'OPTIONS') {
    applyGoogleWorkspaceCors(req, res);
    res.writeHead(204);
    res.end();
    return;
  }
  if (isGoogleWorkspaceRoute || isAttendanceGatewayRoute || isPhase007OperationRoute || isConversationRoute || isCompanyOsRoute || isHrOperationsRoute) {
    applyGoogleWorkspaceCors(req, res);
  }

  if (url.pathname === '/' || url.pathname === '/health') {
    sendJson(res, 200, {
      ok: true,
      service: 'zawolf-notification-dispatcher',
      release: notificationRuntimeRelease,
      notificationListener: notificationListenerOwner && notificationUnsubscribe
        ? 'connected'
        : 'standby',
      backgroundScheduler: backgroundSchedulerEnabled ? 'internal' : 'external_cron',
      // The app ID is public and is embedded in every mobile build. Returning
      // it lets support verify that Hostinger sends through the same OneSignal
      // app that the installed iOS and Android clients registered with. The
      // REST API key is never included.
      oneSignal: oneSignalConfiguration(),
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
        conversationUploads: {
          workspaceRootConfigured: Boolean(
            process.env.GOOGLE_WORKSPACE_ROOT_FOLDER_ID,
          ),
          oauthConfigured: Boolean(
            process.env.GOOGLE_DRIVE_OAUTH_CLIENT_ID &&
            process.env.GOOGLE_DRIVE_OAUTH_CLIENT_SECRET &&
            process.env.GOOGLE_DRIVE_OAUTH_REFRESH_TOKEN,
          ),
        },
      },
      salesAnalytics: salesAnalyticsHealth(),
      googleWorkspace: {
        configured: Boolean(
          process.env.GOOGLE_SHEETS_SERVICE_ACCOUNT &&
          process.env.GOOGLE_WORKSPACE_ROOT_FOLDER_ID
        ),
      },
      phase007: {
        configuredFlags: [...PHASE007_FLAGS].filter((name) =>
          Boolean(phase007FlagConfig[name]?.enabled),
        ),
      },
      diagnostics,
      time: new Date().toISOString(),
    });
    return;
  }

  if (isConversationRoute) {
    await handleConversationRequest(req, res, url);
    return;
  }

  if (isCompanyOsRoute) {
    const firebaseApp = initializeFirebase();
    await routeCompanyOsRequest({
      req,
      res,
      url,
      db: admin.firestore(firebaseApp),
      verifyToken: (token) => getAuth(firebaseApp).verifyIdToken(token),
      flagConfig: companyOsFlagConfig,
      sendJson,
      readJsonBody,
      uploadRequestAttachment: uploadOperationalRequestAttachment,
    });
    return;
  }

  if (url.pathname === '/operations/feature-flags' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    const enabled = [...PHASE007_FLAGS].filter((name) =>
      isPhase007FlagEnabled(name, phase007FlagConfig, actor.uid),
    );
    sendJson(res, 200, { ok: true, enabled });
    return;
  }

  if (url.pathname === '/operations/manual-attendance/employees' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const employees = await listManualAttendanceEmployees({
        db: admin.firestore(initializeFirebase()),
        actor,
        query: url.searchParams.get('query') || '',
      });
      sendJson(res, 200, { ok: true, employees });
    } catch (error) {
      sendJson(res, /صلاحية/.test(String(error.message || error)) ? 403 : 400, {
        ok: false,
        code: 'manual_attendance_employees_failed',
        error: String(error.message || error),
      });
    }
    return;
  }

  if (url.pathname === '/operations/manual-attendance' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const result = await recordManualAttendance({
        db: admin.firestore(initializeFirebase()),
        admin,
        actor,
        body: await readJsonBody(req),
      });
      sendJson(res, 200, { ok: true, ...result });
    } catch (error) {
      sendJson(res, /صلاحية/.test(String(error.message || error)) ? 403 : 400, {
        ok: false,
        code: 'manual_attendance_failed',
        error: String(error.message || error),
      });
    }
    return;
  }

  const casualOverride = url.pathname.match(/^\/operations\/leaves\/([A-Za-z0-9_-]{8,160})\/(?:auto-approval-override|override-casual)$/);
  if (casualOverride && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      const result = await overrideAutoApprovedCasualLeave({ db: admin.firestore(initializeFirebase()), admin, actor, leaveId: casualOverride[1], body: await readJsonBody(req) });
      sendJson(res, 200, { ok: true, ...result });
    } catch (error) {
      sendJson(res, /صلاحية/.test(String(error.message || error)) ? 403 : 400, { ok: false, code: 'casual_leave_override_failed', error: String(error.message || error) });
    }
    return;
  }

  const casualEditDates = url.pathname.match(/^\/operations\/leaves\/([A-Za-z0-9_-]{8,160})\/(?:edit-casual-dates|edit-dates)$/);
  if (casualEditDates && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      const result = await editCasualLeaveDates({ db: admin.firestore(initializeFirebase()), admin, actor, leaveId: casualEditDates[1], body: await readJsonBody(req) });
      sendJson(res, 200, { ok: true, ...result });
    } catch (error) {
      sendJson(res, /صلاحية/.test(String(error.message || error)) ? 403 : 400, { ok: false, code: 'casual_leave_edit_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/meeting-rooms' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, rooms: await listRooms({ db: admin.firestore(initializeFirebase()), admin, actor }) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'meeting_rooms_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/meeting-approvers' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, approvers: await listMeetingApprovers({ db: admin.firestore(initializeFirebase()) }) });
    } catch (error) {
      console.error('Meeting approvers request failed:', error);
      sendJson(res, 500, { ok: false, code: 'meeting_approvers_failed', error: 'تعذر تحميل مسؤولي الاجتماع. أعد المحاولة.' });
    }
    return;
  }

  if (url.pathname === '/operations/meeting-availability' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    const roomId = String(url.searchParams.get('roomId') || '');
    const startAt = new Date(String(url.searchParams.get('startAt') || ''));
    const endAt = new Date(String(url.searchParams.get('endAt') || ''));
    if (!/^[A-Za-z0-9_-]{8,160}$/.test(roomId) || Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime()) || startAt >= endAt) {
      return sendJson(res, 400, { ok: false, code: 'invalid_meeting_time', error: 'اختر قاعة ووقت بداية ونهاية صحيحين.' });
    }
    try {
      const available = await checkAvailability({ db: admin.firestore(initializeFirebase()), roomId, startAt, endAt });
      sendJson(res, 200, { ok: true, available, message: available ? 'القاعة متاحة في هذا الوقت.' : 'القاعة مشغولة في هذا الوقت. اختر موعداً أو قاعة أخرى.' });
    } catch (error) {
      console.error('Meeting availability request failed:', error);
      sendJson(res, 500, { ok: false, code: 'meeting_availability_failed', error: 'تعذر التحقق من توفر القاعة. أعد المحاولة.' });
    }
    return;
  }

  if (url.pathname === '/operations/meeting-requests' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    const queue = url.searchParams.get('queue') === 'true';
    try {
      sendJson(res, 200, { ok: true, requests: await listMeetingRequests({ db: admin.firestore(initializeFirebase()), actor, queue }) });
    } catch (error) {
      console.error('Meeting requests listing failed:', error);
      sendJson(res, 500, { ok: false, code: 'meeting_requests_failed', error: 'تعذر تحميل طلبات الاجتماعات. أعد المحاولة.' });
    }
    return;
  }

  if (url.pathname === '/operations/meeting-rooms' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 201, { ok: true, ...(await saveRoom({ db: admin.firestore(initializeFirebase()), admin, actor, body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'meeting_room_save_failed', error: String(error.message || error) });
    }
    return;
  }

  const meetingRoomEdit = url.pathname.match(/^\/operations\/meeting-rooms\/([A-Za-z0-9_-]{1,160})$/);
  if (meetingRoomEdit && req.method === 'PATCH') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, ...(await saveRoom({ db: admin.firestore(initializeFirebase()), admin, actor, roomId: meetingRoomEdit[1], body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'meeting_room_save_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/meeting-requests' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 201, { ok: true, ...(await createMeeting({ db: admin.firestore(initializeFirebase()), admin, actor, body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'meeting_request_failed', error: String(error.message || error) });
    }
    return;
  }

  const meetingDecision = url.pathname.match(/^\/operations\/meeting-requests\/([A-Za-z0-9_-]{8,160})\/decision$/);
  if (meetingDecision && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, ...(await decideMeeting({ db: admin.firestore(initializeFirebase()), admin, actor, requestId: meetingDecision[1], body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'meeting_decision_failed', error: String(error.message || error) });
    }
    return;
  }

  const meetingCancel = url.pathname.match(/^\/operations\/meeting-requests\/([A-Za-z0-9_-]{8,160})\/cancel$/);
  if (meetingCancel && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, ...(await cancelMeeting({ db: admin.firestore(initializeFirebase()), admin, actor, requestId: meetingCancel[1], body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'meeting_cancel_failed', error: String(error.message || error) });
    }
    return;
  }

  if ((url.pathname === '/operations/custom-request-types' || url.pathname === '/operations/custom-request-directory') && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, types: await listCustomRequestTypes({ db: admin.firestore(initializeFirebase()), actor }) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'list_request_types_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/custom-request-directory' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, users: await listCustomRequestDirectory({ db: admin.firestore(initializeFirebase()), actor }) });
    } catch (error) {
      sendJson(res, 403, { ok: false, code: 'custom_request_directory_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/custom-request-types' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, ...(await saveCustomRequestType({ db: admin.firestore(initializeFirebase()), admin, actor, body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'save_request_type_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/custom-requests' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      const queue = url.searchParams.get('queue') === 'true';
      sendJson(res, 200, { ok: true, requests: await listCustomRequests({ db: admin.firestore(initializeFirebase()), actor, queue }) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'list_custom_requests_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/custom-requests' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 201, { ok: true, ...(await createCustomRequest({ db: admin.firestore(initializeFirebase()), admin, actor, body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'create_custom_request_failed', error: String(error.message || error) });
    }
    return;
  }

  const customDecision = url.pathname.match(/^\/operations\/custom-requests\/([A-Za-z0-9_-]{8,160})\/decision$/);
  if (customDecision && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
    try {
      sendJson(res, 200, { ok: true, ...(await decideCustomRequest({ db: admin.firestore(initializeFirebase()), admin, actor, requestId: customDecision[1], body: await readJsonBody(req) })) });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'custom_decision_failed', error: String(error.message || error) });
    }
    return;
  }

  if (url.pathname === '/operations/employee-timeline' ||
      /^\/operations\/visibility\/[A-Za-z0-9_-]{1,128}$/.test(url.pathname)) {
    await handleOperationalVisibilityRequest(req, res, url);
    return;
  }

  if (url.pathname === '/operations/request-management/archive' && req.method === 'POST') {
    await handleRequestManagementArchive(req, res);
    return;
  }

  if (url.pathname === '/operations/request-management/notify' && req.method === 'POST') {
    await handleRequestManagementNotification(req, res);
    return;
  }

  if (url.pathname === '/operations/request-approval-routing/field-missions' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const result = await createFieldMission({
        db: admin.firestore(initializeFirebase()), admin, actor,
        body: await readJsonBody(req),
      });
      sendJson(res, 201, { ok: true, ...result });
    } catch (error) {
      sendJson(res, /صلاحية/.test(String(error.message || error)) ? 403 : 400, {
        ok: false, code: 'field_mission_route_failed', error: String(error.message || error),
      });
    }
    return;
  }

  if (url.pathname === '/operations/request-approval-routing/employee-field-missions' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) { sendJson(res, 401, { ok: false, code: 'session_expired' }); return; }
    try {
      const result = await createEmployeeFieldMission({
        db: admin.firestore(initializeFirebase()), admin, actor,
        body: await readJsonBody(req),
      });
      sendJson(res, 201, { ok: true, ...result });
    } catch (error) {
      sendJson(res, 400, { ok: false, code: 'employee_field_mission_route_failed', error: String(error.message || error) });
    }
    return;
  }

  const fieldMissionDecision = url.pathname.match(/^\/operations\/request-approval-routing\/field-missions\/([A-Za-z0-9_-]{8,128})\/decision$/);
  if (fieldMissionDecision && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const result = await decideFieldMission({
        db: admin.firestore(initializeFirebase()), admin, actor,
        requestId: fieldMissionDecision[1], body: await readJsonBody(req),
      });
      sendJson(res, 200, { ok: true, ...result });
    } catch (error) {
      sendJson(res, /انتظار قرارك|صلاحية/.test(String(error.message || error)) ? 403 : 400, {
        ok: false, code: 'field_mission_decision_failed', error: String(error.message || error),
      });
    }
    return;
  }

  if (url.pathname === '/operations/sales-indicators' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canViewSalesIndicators(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    try {
      const filters = canonicalSalesFilters({
        startDate: url.searchParams.get('startDate'),
        endDate: url.searchParams.get('endDate'),
        company: url.searchParams.get('company'),
        sales: url.searchParams.getAll('sales'),
        teleSales: url.searchParams.getAll('teleSales'),
        entryChannel: url.searchParams.get('entryChannel'),
        salesTarget: url.searchParams.get('salesTarget'),
        teleTarget: url.searchParams.get('teleTarget'),
      });
      if (!/^\d{4}-\d{2}-\d{2}$/.test(filters.startDate) ||
          !/^\d{4}-\d{2}-\d{2}$/.test(filters.endDate)) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const version = salesFilterVersion(filters);
      const periodKey = filters.endDate.slice(0, 7);
      const expectedId = `${periodKey}_${version}`;
      const snapshot = await admin.firestore().collection('salesKpiSnapshots').doc(expectedId).get();
      if (!snapshot.exists) {
        sendJson(res, 409, {
          ok: false,
          code: 'snapshot_not_ready',
          filterVersion: version,
          safeMessage: 'لم تكتمل مزامنة هذه الفلاتر بعد. أعد المحاولة بعد المزامنة.',
        });
        return;
      }
      const data = snapshot.data() || {};
      sendJson(res, 200, {
        ok: true,
        snapshot: {
          ...data,
          syncedAt: data.syncedAt?.toDate?.().toISOString() || null,
        },
      });
    } catch (error) {
      recordWorkspaceDiagnostic('sales_indicators_query', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/sales-indicators/sync' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canViewSalesIndicators(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    if (runningSalesKpiSync) {
      sendJson(res, 202, { ok: true, code: 'already_running' });
      return;
    }
    try {
      const payload = (await readJsonBody(req, 8 * 1024)) || {};
      const defaultCycle = cycleFor();
      const startDate = payload.startDate || defaultCycle.startDate;
      const endDate = payload.endDate || defaultCycle.endDate;
      const filters = canonicalSalesFilters({ ...payload, startDate, endDate });
      if (!/^\d{4}-\d{2}-\d{2}$/.test(filters.startDate) ||
          !/^\d{4}-\d{2}-\d{2}$/.test(filters.endDate)) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const result = await syncSalesKpis(filters);
      diagnostics.lastSalesKpiAt = new Date().toISOString();
      diagnostics.lastSalesKpiResult = result;
      sendJson(res, 200, { ok: true, code: 'synced', ...result });
    } catch (error) {
      recordWorkspaceDiagnostic('sales_indicators_sync', error);
      sendJson(res, 503, {
        ok: false,
        code: 'temporarily_unavailable',
        safeMessage: 'تعذر تحديث مؤشرات المبيعات الآن. أعد المحاولة لاحقاً.',
      });
    } finally {
      runningSalesKpiSync = null;
    }
    return;
  }

  if (url.pathname === '/operations/sales-indicators/mappings' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canManageSalesMappings(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 8 * 1024);
      const providerRole = String(payload.providerRole || '').trim().toLowerCase();
      const providerKey = String(payload.providerKey || '').trim();
      const employeeUserId = String(payload.employeeUserId || '').trim();
      if (!['sales', 'tele_sales'].includes(providerRole) ||
          !providerKey || providerKey.length > 128 ||
          !/^[A-Za-z0-9_-]{1,128}$/.test(employeeUserId)) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const db = admin.firestore();
      const employee = await db.collection('users').doc(employeeUserId).get();
      const user = employee.data() || {};
      if (!employee.exists || user.isActive !== true) {
        sendJson(res, 404, { ok: false, code: 'employee_not_found' });
        return;
      }
      const mappingId = mappingDocumentId(providerRole, providerKey);
      const mapping = {
        providerRole,
        providerKey,
        userId: employeeUserId,
        employeeId: String(user.employeeId || ''),
        employeeName: String(user.displayName || user.name || ''),
        active: true,
        version: 1,
        updatedBy: actor.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await db.runTransaction(async (transaction) => {
        transaction.set(db.collection('salesIdentityMappings').doc(mappingId), mapping);
        transaction.set(db.collection('operationalAudit').doc(`sales_mapping:${mappingId}:${Date.now()}`), {
          action: 'sales_identity_mapping_updated',
          actorId: actor.uid,
          targetUserId: employeeUserId,
          providerRole,
          providerKey,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      sendJson(res, 200, { ok: true, code: 'mapping_saved', mapping: {
        ...mapping,
        updatedAt: null,
      } });
    } catch (error) {
      recordWorkspaceDiagnostic('sales_mapping_update', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/diagnostics' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 8 * 1024);
      const result = await recordDiagnosticEvent(admin.firestore(), payload, {
        actorId: actor.uid,
      });
      const safeEvent = sanitizeDiagnosticEvent(payload);
      if (safeEvent?.feature === 'attendance_checkin' ||
          (safeEvent?.feature === 'request_visibility' &&
            safeEvent.metadata.operation === 'request_decision')) {
        console.info('Client operation diagnostic:', {
          actorId: actor.uid,
          feature: safeEvent.feature,
          safeCode: safeEvent.safeCode,
          operation: safeEvent.metadata.operation || '',
          stage: safeEvent.metadata.state || '',
          accepted: result.accepted,
        });
      }
      // Never echo input, raw errors, actor IDs, or provider failures.
      sendJson(res, result.accepted ? 202 : 400, {
        ok: result.accepted,
        code: result.accepted ? 'accepted' : 'invalid',
      });
    } catch (error) {
      recordWorkspaceDiagnostic('phase007_diagnostics', error);
      sendJson(res, 202, { ok: true, code: 'accepted' });
    }
    return;
  }

  if (url.pathname === '/operations/diagnostics' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canViewDiagnostics(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    try {
      const requestedLimit = Number.parseInt(url.searchParams.get('limit') || '100', 10);
      const limit = Math.max(1, Math.min(Number.isFinite(requestedLimit) ? requestedLimit : 100, 100));
      const release = String(url.searchParams.get('release') || '').trim().slice(0, 80);
      const feature = String(url.searchParams.get('feature') || '').trim().toLowerCase().slice(0, 64);
      const safeCode = String(url.searchParams.get('safeCode') || '').trim().toLowerCase().slice(0, 64);
      // One bounded query avoids a composite-index dependency. Optional report
      // filters are applied only to the sanitized aggregate documents.
      const snapshot = await admin.firestore()
        .collection('diagnosticAggregates')
        .orderBy('lastSeenAt', 'desc')
        .limit(250)
        .get();
      const reports = [];
      for (const doc of snapshot.docs) {
        const data = doc.data() || {};
        const sanitized = sanitizeDiagnosticEvent(data);
        if (!sanitized) continue;
        if (release && sanitized.release !== release) continue;
        if (feature && sanitized.feature !== feature) continue;
        if (safeCode && sanitized.safeCode !== safeCode) continue;
        reports.push({
          fingerprint: String(data.fingerprint || doc.id).slice(0, 64),
          ...sanitized,
          count: Math.max(0, Number(data.count || 0)),
          lastSeenAt: String(data.lastSeenAt || '').slice(0, 40),
        });
        if (reports.length >= limit) break;
      }
      const groups = Object.values(reports.reduce((result, report) => {
        const key = `${report.release}|${report.feature}|${report.safeCode}`;
        const current = result[key] || {
          release: report.release,
          feature: report.feature,
          safeCode: report.safeCode,
          count: 0,
          fingerprints: 0,
        };
        current.count += report.count;
        current.fingerprints += 1;
        result[key] = current;
        return result;
      }, {}));
      sendJson(res, 200, { ok: true, reports, groups });
    } catch (error) {
      recordWorkspaceDiagnostic('phase007_diagnostic_report', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/notification-read-all' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 4 * 1024);
      const result = await markAllNotificationsRead({
        db: admin.firestore(),
        fieldValue: admin.firestore.FieldValue,
        actorId: actor.uid,
        input: payload,
      });
      sendJson(res, result.ok ? 200 : 400, result);
    } catch (error) {
      recordWorkspaceDiagnostic('notification_read_all', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/resolve-notification' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 4 * 1024);
      const result = await resolveNotificationDestination({
        db: admin.firestore(),
        actor,
        input: payload,
      });
      const status = result.ok ? 200 : result.code === 'not_found' ? 404 : 400;
      sendJson(res, status, result);
    } catch (error) {
      recordWorkspaceDiagnostic('notification_resolve', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/attendance-corrections' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 16 * 1024);
      const operationId = String(payload.operationId || req.headers['x-operation-id'] || '').trim();
      const attendanceId = String(payload.attendanceId || '').trim();
      const reason = String(payload.reason || '').trim();
      const requestedCheckIn = new Date(String(payload.requestedCheckIn || ''));
      if (!isValidCorrectionSubmission({
        operationId, attendanceId, reason, requestedCheckIn,
      })) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const db = admin.firestore();
      const requestRef = db.collection('attendanceCorrectionRequests').doc(operationId);
      const lockRef = db.collection('attendanceCorrectionLocks').doc(attendanceId);
      const attendanceRef = db.collection('attendance').doc(attendanceId);
      const userRef = db.collection('users').doc(actor.uid);
      let result = { code: 'unexpected', requestId: null };
      await db.runTransaction(async (transaction) => {
        const [existing, lock, attendance, employee] = await Promise.all([
          transaction.get(requestRef),
          transaction.get(lockRef),
          transaction.get(attendanceRef),
          transaction.get(userRef),
        ]);
        if (existing.exists) {
          result = { code: 'submitted', requestId: existing.id };
          return;
        }
        const attendanceData = attendance.data() || {};
        const original = attendanceData.checkInTime;
        if (!attendance.exists || attendanceData.userId !== actor.uid || !original?.toDate) {
          result = { code: 'access_denied', requestId: null };
          return;
        }
        const originalDate = original.toDate();
        if (!isSameCairoAttendanceDay(requestedCheckIn, originalDate)) {
          result = { code: 'validation_failed', requestId: null };
          return;
        }
        if (lock.exists && lock.data()?.status === 'pending_hr') {
          result = { code: 'already_pending', requestId: lock.data()?.requestId || null };
          return;
        }
        const employeeData = employee.data() || {};
        transaction.set(requestRef, {
          requestId: operationId,
          operationId,
          userId: actor.uid,
          employeeId: String(employeeData.employeeId || ''),
          employeeName: String(employeeData.displayName || employeeData.name || ''),
          department: String(employeeData.department || ''),
          attendanceId,
          attendanceDate: String(attendanceData.date || ''),
          originalCheckInTime: original,
          requestedCheckInTime: admin.firestore.Timestamp.fromDate(requestedCheckIn),
          reason,
          status: 'pending_hr',
          submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(lockRef, {
          requestId: operationId,
          status: 'pending_hr',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(db.collection('operationalAudit').doc(`attendance_correction:${operationId}`), {
          action: 'attendance_correction_submitted',
          actorId: actor.uid,
          requestId: operationId,
          attendanceId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        result = { code: 'submitted', requestId: operationId };
      });
      sendJson(res, result.code === 'submitted' || result.code === 'already_pending' ? 200 : 400, {
        ok: result.code === 'submitted' || result.code === 'already_pending',
        code: result.code,
      });
    } catch (error) {
      recordWorkspaceDiagnostic('attendance_correction_submit', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/developer-tools/me' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    const entitlement = await admin.firestore()
      .collection('developerToolEntitlements')
      .doc(actor.uid)
      .get();
    const data = entitlement.data() || {};
    const expiresAt = data.expiresAt?.toDate?.();
    const explicitEntitlement = entitlement.exists &&
      isDeveloperToolsEntitlementActive(data);
    // A manager has made an explicit, narrowly-scoped grant.  Do not gate that
    // grant behind the pilot flag: the scopes themselves remain limited by the
    // entitlement module and do not enable USB debugging, mock locations, or
    // any attendance bypass.
    const active = explicitEntitlement;
    sendJson(res, 200, {
      ok: true,
      enabled: active,
      entitlement: active ? {
        scopes: normalizeDeveloperToolScopes(data.scopes),
        expiresAt: expiresAt instanceof Date ? expiresAt.toISOString() : null,
        permanent: data.permanent === true,
      } : null,
    });
    return;
  }

  if (url.pathname === '/operations/employee-password-reset' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!isHrOrAdmin(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 4 * 1024);
      const employeeUserId = String(payload.employeeUserId || '').trim();
      const operationId = String(payload.operationId || '').trim();
      if (!/^[A-Za-z0-9_-]{1,128}$/.test(employeeUserId) ||
          !/^[A-Za-z0-9_-]{1,256}$/.test(operationId)) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const firebaseApp = initializeFirebase();
      const db = admin.firestore(firebaseApp);
      const employeeRef = db.collection('users').doc(employeeUserId);
      const employee = await employeeRef.get();
      if (!employee.exists || employee.data()?.isActive === false) {
        sendJson(res, 404, { ok: false, code: 'target_not_found' });
        return;
      }
      // The password is server-owned and deliberately never accepted from the
      // browser or mobile client. Revoke sessions so this takes effect now.
      await getAuth(firebaseApp).updateUser(employeeUserId, { password: 'ZW@0000' });
      await getAuth(firebaseApp).revokeRefreshTokens(employeeUserId);
      await db.runTransaction(async (transaction) => {
        transaction.set(employeeRef, {
          passwordChangedAt: admin.firestore.FieldValue.delete(),
          passwordResetAt: admin.firestore.FieldValue.serverTimestamp(),
          passwordResetByUserId: actor.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(db.collection('operationalAudit').doc(
          `password_reset_default:${employeeUserId}:${operationId}`,
        ), {
          action: 'password_reset_to_company_default',
          actorId: actor.uid,
          targetUserId: employeeUserId,
          operationId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      sendJson(res, 200, { ok: true, code: 'password_reset' });
    } catch (error) {
      recordWorkspaceDiagnostic('employee_password_reset', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/developer-tools/entitlements' && req.method === 'GET') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canManageDeveloperTools(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    try {
      const snapshot = await admin.firestore()
        .collection('developerToolEntitlements')
        .limit(500)
        .get();
      const entitlements = snapshot.docs
        .map((document) => {
          const data = document.data() || {};
          const expiresAt = data.expiresAt?.toDate?.();
          return {
            employeeUserId: String(data.employeeUserId || document.id),
            scopes: normalizeDeveloperToolScopes(data.scopes),
            permanent: data.permanent === true,
            expiresAt: expiresAt instanceof Date ? expiresAt.toISOString() : null,
            grantedByUserId: String(data.grantedByUserId || ''),
            active: isDeveloperToolsEntitlementActive(data),
          };
        })
        .filter((entitlement) => entitlement.active);
      sendJson(res, 200, { ok: true, entitlements });
    } catch (error) {
      recordWorkspaceDiagnostic('developer_tools_list', error);
      sendJson(res, 503, { ok: false, code: 'temporarily_unavailable' });
    }
    return;
  }

  if (url.pathname === '/operations/developer-tools/entitlements' && req.method === 'POST') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canManageDeveloperTools(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    try {
      const payload = await readJsonBody(req, 8 * 1024);
      const employeeUserId = String(payload.employeeUserId || '').trim();
      const scopes = normalizeDeveloperToolScopes(payload.scopes);
      // A missing expiry is intentionally a permanent, diagnostics-only
      // entitlement. Older web clients did not always send `permanent` when
      // the HR user selected "no expiry", which previously produced a 400.
      // The scope allow-list remains enforced by normalizeDeveloperToolScopes.
      const permanent = payload.permanent === true || !payload.expiresAt;
      const expiresAt = permanent ? null : new Date(String(payload.expiresAt));
      if (!/^[A-Za-z0-9_-]{1,128}$/.test(employeeUserId) ||
          scopes.length === 0 || (!permanent && !isDeveloperToolsExpiryValid(expiresAt))) {
        sendJson(res, 400, { ok: false, code: 'validation_failed' });
        return;
      }
      const db = admin.firestore();
      const targetRef = db.collection('users').doc(employeeUserId);
      const entitlementRef = db.collection('developerToolEntitlements').doc(employeeUserId);
      await db.runTransaction(async (transaction) => {
        const target = await transaction.get(targetRef);
        // Older accounts do not all carry `isActive`; only an explicitly
        // disabled account must be rejected.
        if (!target.exists || target.data()?.isActive === false) {
          const failure = new Error('target_account_not_found');
          failure.code = 'target_account_not_found';
          throw failure;
        }
        transaction.set(entitlementRef, {
          employeeUserId,
          scopes,
          expiresAt: expiresAt ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
          permanent,
          grantedByUserId: actor.uid,
          grantedAt: admin.firestore.FieldValue.serverTimestamp(),
          revokedAt: null,
          version: 1,
        });
        transaction.set(db.collection('operationalAudit').doc(
          `developer_tools_granted:${employeeUserId}:${permanent ? 'permanent' : expiresAt.getTime()}`,
        ), {
          action: 'developer_tools_granted',
          actorId: actor.uid,
          targetUserId: employeeUserId,
          scopes,
          expiresAt: expiresAt ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
          permanent,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      sendJson(res, 200, { ok: true, code: 'granted' });
    } catch (error) {
      recordWorkspaceDiagnostic('developer_tools_grant', error);
      sendJson(res, error?.code === 'target_account_not_found' ? 404 : 503, {
        ok: false,
        code: error?.code === 'target_account_not_found'
          ? 'target_not_found'
          : 'temporarily_unavailable',
      });
    }
    return;
  }

  const revokeDeveloperToolsMatch = url.pathname.match(
    /^\/operations\/developer-tools\/entitlements\/([A-Za-z0-9_-]{1,128})$/,
  );
  if (revokeDeveloperToolsMatch && req.method === 'DELETE') {
    const actor = await authorizeWorkspaceRequest(req);
    if (!actor) {
      sendJson(res, 401, { ok: false, code: 'session_expired' });
      return;
    }
    if (!canManageDeveloperTools(actor)) {
      sendJson(res, 403, { ok: false, code: 'access_denied' });
      return;
    }
    const employeeUserId = revokeDeveloperToolsMatch[1];
    const db = admin.firestore();
    await db.runTransaction(async (transaction) => {
      const entitlementRef = db.collection('developerToolEntitlements').doc(employeeUserId);
      transaction.set(entitlementRef, {
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
        revokedByUserId: actor.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(db.collection('operationalAudit').doc(
        `developer_tools_revoked:${employeeUserId}:${Date.now()}`,
      ), {
        action: 'developer_tools_revoked',
        actorId: actor.uid,
        targetUserId: employeeUserId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    sendJson(res, 200, { ok: true, code: 'revoked' });
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

  if ((url.pathname === '/company-workspace/reports/audit' ||
      url.pathname === '/company-workspace/v2/reports/audit') && req.method === 'POST') {
    await handleWorkspaceAuditReport(req, res);
    return;
  }

  if (url.pathname === '/company-workspace/v2/audit' && req.method === 'GET') {
    await handleWorkspaceAuditEvents(req, res, url);
    return;
  }

  if (url.pathname === '/company-workspace/v2/reports/hr' && req.method === 'POST') {
    await handleWorkspaceHrReport(req, res);
    return;
  }

  if (url.pathname === '/company-workspace/v2/resources' && req.method === 'GET') {
    await handleCompanyWorkspaceV2Resources(req, res, url);
    return;
  }

  if (url.pathname === '/company-workspace/v2/pilot' &&
      ['GET', 'PUT'].includes(req.method)) {
    await handleCompanyWorkspaceV2Pilot(req, res);
    return;
  }

  if ((url.pathname === '/company-workspace/v2/access/grants' ||
      /^\/company-workspace\/v2\/access\/grants\/[A-Za-z0-9_-]{1,128}$/.test(url.pathname)) &&
      ['GET', 'POST', 'DELETE'].includes(req.method)) {
    await handleCompanyWorkspaceV2Access(req, res, url);
    return;
  }

  if (url.pathname === '/company-workspace/v2/access/import' && req.method === 'POST') {
    await handleCompanyWorkspaceV2SourceImport(req, res);
    return;
  }

  if (url.pathname === '/company-workspace/v2/operations' && req.method === 'POST') {
    await handleCompanyWorkspaceV2Operations(req, res);
    return;
  }

  if (/^\/company-workspace\/v2\/resources\/[^/]+\/content$/.test(url.pathname) &&
      req.method === 'GET') {
    await handleCompanyWorkspaceV2Download(req, res, url);
    return;
  }

  if (/^\/company-workspace\/v2\/resources\/[^/]+\/sheet$/.test(url.pathname) &&
      req.method === 'GET') {
    await handleCompanyWorkspaceV2Sheet(req, res, url);
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

  if (url.pathname === '/attendance/security-review' && req.method === 'POST') {
    await handleAttendanceSecurityReview(req, res);
    return;
  }

  if (url.pathname.startsWith('/attendance/locations/')) {
    await handleAttendanceLocationAssignments(req, res, url);
    return;
  }

  if (url.pathname.startsWith('/company-workspace/resources/')) {
    await handleCompanyWorkspace(req, res, url);
    return;
  }

  if (isDeveloperApiRoute) {
    // External credentials are verified only by the developer-API module.
    // Firebase session verification is required solely for its owner routes.
    const actor = url.pathname.startsWith('/developer-api/v1/admin/')
      ? await authorizeWorkspaceRequest(req)
      : null;
    await require('./developer-api/router').handleDeveloperApiRequest({
      req, res, url, db: admin.firestore(initializeFirebase()), admin, actor, readJsonBody, sendJson,
    });
    return;
  }

  sendJson(res, 404, { ok: false, error: 'Not found' });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`ZaWolf notification dispatcher listening on port ${port}`);
  // Firestore wakes the push dispatcher as soon as a notification document is
  // created. Scheduled work remains on a five-minute clock for attendance.
  if (notificationListenerEnabled) {
    startNotificationListener();
    // Hostinger may briefly run more than one Node worker during deployment or
    // restarts. Renew the lease so exactly one worker retains the listener.
    setInterval(() => void ensureNotificationListenerLeader(), 2 * 60 * 1000);
  } else {
    console.log('Notification listener is disabled for this runtime.');
  }
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
