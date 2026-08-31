'use strict';

const crypto = require('node:crypto');

const REQUIRED_ACTORS = Object.freeze([
  'employee', 'it_support', 'it_manager', 'finance', 'manager',
  'admin', 'super_admin', 'inactive', 'out_of_scope',
]);
const FLAGS = Object.freeze([
  'company_os_portal_v1', 'company_os_it_v1',
  'company_os_requests_v1', 'company_os_operations_v1',
  'company_os_organization_v1',
]);
const FORBIDDEN_RESPONSE_KEYS = /^(?:privateNote|privateNotes|password|token|authorization|secret|stack|rawError)$/i;
const FORBIDDEN_RESPONSE_TEXT = /(?:Bearer\s+[A-Za-z0-9._~+/=-]+|\[cloud_firestore\/|firebase(?:admin|error)?|googleapis\.com)/i;
const PRODUCTION_HOSTS = new Set([
  'notification.zawolf.ai',
  'zawolf-hr-system-60317.web.app',
  'zawolf-hr-system-60317.firebaseapp.com',
]);
const NON_PRODUCTION_HOST = /(?:^localhost$|^127\.0\.0\.1$|(?:^|[.-])(?:test|testing|staging|stage|nonprod|non-production|dev|emulator)(?:[.-]|$))/i;

const EXPECTED_ROLES = Object.freeze({
  employee: ['employee'], it_support: ['it_support'], it_manager: ['it_manager'],
  finance: ['finance'], manager: ['manager'], admin: ['admin', 'hr_admin'],
  super_admin: ['super_admin'], out_of_scope: ['employee'],
});

function acceptanceError(message) {
  const error = new Error(message);
  error.code = 'acceptance_failed';
  return error;
}

function validateBaseUrl(value) {
  let url;
  try { url = new URL(String(value || '')); } catch (_) { throw acceptanceError('COMPANY_OS_ACCEPTANCE_BASE_URL is invalid.'); }
  if (!['https:', 'http:'].includes(url.protocol)) throw acceptanceError('Acceptance URL must use HTTP or HTTPS.');
  if (PRODUCTION_HOSTS.has(url.hostname.toLowerCase())) throw acceptanceError('Production Company OS hosts are blocked.');
  if (!NON_PRODUCTION_HOST.test(url.hostname)) throw acceptanceError('Acceptance URL must clearly identify a non-production host.');
  if (url.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(url.hostname)) {
    throw acceptanceError('Remote acceptance requires HTTPS.');
  }
  url.pathname = url.pathname.replace(/\/$/, '');
  url.search = '';
  url.hash = '';
  return url.toString().replace(/\/$/, '');
}

function validateLegacyUrls(value) {
  let input;
  try { input = JSON.parse(String(value || '')); } catch (_) { throw acceptanceError('COMPANY_OS_ACCEPTANCE_LEGACY_URLS_JSON must be valid JSON.'); }
  if (!input || Array.isArray(input) || typeof input !== 'object') throw acceptanceError('Legacy fallback URLs must be a JSON object.');
  return Object.fromEntries(FLAGS.map((flag) => {
    const raw = String(input[flag] || '').trim();
    if (!raw) throw acceptanceError(`Missing legacy fallback URL for ${flag}.`);
    let url;
    try { url = new URL(raw); } catch (_) { throw acceptanceError(`Invalid legacy fallback URL for ${flag}.`); }
    validateBaseUrl(url.origin);
    return [flag, url.toString()];
  }));
}

function parseActorTokens(value) {
  let input;
  try { input = JSON.parse(String(value || '')); } catch (_) { throw acceptanceError('COMPANY_OS_ACCEPTANCE_TOKENS_JSON must be valid JSON.'); }
  if (!input || Array.isArray(input) || typeof input !== 'object') throw acceptanceError('Acceptance tokens must be a JSON object.');
  const missing = REQUIRED_ACTORS.filter((alias) => !input[alias]);
  if (missing.length) throw acceptanceError(`Missing acceptance actor aliases: ${missing.join(', ')}.`);
  return Object.fromEntries(REQUIRED_ACTORS.map((alias) => {
    const raw = input[alias];
    const token = typeof raw === 'string' ? raw : raw?.token;
    if (typeof token !== 'string' || token.trim().length < 16) throw acceptanceError(`Invalid token for actor alias ${alias}.`);
    return [alias, { token: token.trim() }];
  }));
}

function hasForbiddenData(value, path = '$') {
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index += 1) {
      const found = hasForbiddenData(value[index], `${path}[${index}]`);
      if (found) return found;
    }
    return null;
  }
  if (value && typeof value === 'object') {
    for (const [key, child] of Object.entries(value)) {
      if (FORBIDDEN_RESPONSE_KEYS.test(key)) return `${path}.${key}`;
      const found = hasForbiddenData(child, `${path}.${key}`);
      if (found) return found;
    }
    return null;
  }
  return typeof value === 'string' && FORBIDDEN_RESPONSE_TEXT.test(value) ? path : null;
}

function safeEvidence(value) {
  if (Array.isArray(value)) return value.map(safeEvidence);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !FORBIDDEN_RESPONSE_KEYS.test(key) && !/(?:uid|email|displayName|employeeId)/i.test(key))
    .map(([key, child]) => [key, safeEvidence(child)]));
}

function createMetrics() { return { requests: [] }; }

function metricsSummary(metrics) {
  const requests = Array.isArray(metrics?.requests) ? metrics.requests : [];
  const durations = requests.map((item) => item.durationMs).sort((a, b) => a - b);
  const percentileIndex = durations.length ? Math.max(0, Math.ceil(durations.length * 0.95) - 1) : 0;
  const safeErrorCounts = {};
  for (const item of requests) {
    if (item.safeCode) safeErrorCounts[item.safeCode] = (safeErrorCounts[item.safeCode] || 0) + 1;
  }
  return {
    requestCount: requests.length,
    p95LatencyMs: durations.length ? durations[percentileIndex] : 0,
    deniedScopeAttempts: requests.filter((item) => item.status === 403).length,
    maxReturnedItems: requests.reduce((maximum, item) => Math.max(maximum, item.items || 0), 0),
    safeErrorCounts,
  };
}

async function requestJson({ fetchImpl, baseUrl, token, path, method = 'GET', body, timeoutMs = 12000, metrics }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const startedAt = Date.now();
  let status = null;
  let payload = null;
  try {
    const response = await fetchImpl(`${baseUrl}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${token}`,
        accept: 'application/json',
        ...(body ? { 'content-type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });
    status = response.status;
    const text = await response.text();
    payload = {};
    try { payload = text ? JSON.parse(text) : {}; } catch (_) { throw acceptanceError(`Non-JSON response from ${path}.`); }
    const forbidden = hasForbiddenData(payload);
    if (forbidden) throw acceptanceError(`Private/provider data found at ${forbidden}.`);
    return { status: response.status, payload };
  } catch (error) {
    if (error?.name === 'AbortError') throw acceptanceError(`Request timed out: ${path}.`);
    throw error;
  } finally {
    clearTimeout(timer);
    if (metrics?.requests) {
      metrics.requests.push({
        method, route: path.split('?')[0], status,
        durationMs: Math.max(0, Date.now() - startedAt),
        safeCode: payload?.safeCode || payload?.code || null,
        items: Array.isArray(payload?.items) ? payload.items.length : 0,
      });
    }
  }
}

function assertResponse(result, expectedStatus, label) {
  if (result.status !== expectedStatus) {
    throw acceptanceError(`${label} expected HTTP ${expectedStatus}, received ${result.status} (${result.payload?.safeCode || result.payload?.code || 'unknown'}).`);
  }
  if (expectedStatus === 200 && result.payload?.ok !== true) throw acceptanceError(`${label} did not return ok=true.`);
}

function assertBoundedList(result, label, limit = 10) {
  assertResponse(result, 200, label);
  if (!Array.isArray(result.payload.items) || result.payload.items.length > limit) {
    throw acceptanceError(`${label} exceeded its bounded page size.`);
  }
}

async function runRoleMatrix({ baseUrl, actors, fetchImpl = fetch }) {
  const evidence = [];
  const metrics = createMetrics();
  for (const alias of REQUIRED_ACTORS) {
    const result = await requestJson({ fetchImpl, baseUrl, token: actors[alias].token, path: '/company-os/me', metrics });
    if (alias === 'inactive') {
      assertResponse(result, 403, 'inactive actor');
      evidence.push({ actor: alias, authentication: 'denied', status: result.status });
      continue;
    }
    assertResponse(result, 200, `${alias} identity`);
    const role = String(result.payload.actor?.role || '');
    if (!EXPECTED_ROLES[alias].includes(role)) throw acceptanceError(`${alias} resolved to an unexpected role.`);
    const flags = result.payload.flags || {};
    if (alias === 'out_of_scope') {
      if (FLAGS.some((flag) => flags[flag] !== false)) throw acceptanceError('Out-of-scope actor is inside a pilot audience.');
    } else if (FLAGS.some((flag) => flags[flag] !== true)) {
      throw acceptanceError(`${alias} must be allowlisted for every slice during role-matrix acceptance.`);
    }
    evidence.push({ actor: alias, authentication: 'allowed', role, flags: safeEvidence(flags) });
  }

  const listChecks = [
    ['employee', '/company-os/tickets?scope=self&limit=10', 200, true],
    ['employee', '/company-os/requests?scope=self&limit=10', 200, true],
    ['employee', '/company-os/assets?limit=10', 403, false],
    ['employee', '/company-os/operations/search?type=ticket&limit=10', 403, false],
    ['employee', '/company-os/organization/hierarchy?limit=10', 200, true],
    ['it_support', '/company-os/assets?limit=10', 200, true],
    ['it_support', '/company-os/operations/search?type=ticket&limit=10', 403, false],
    ['it_manager', '/company-os/assets?limit=10', 200, true],
    ['it_manager', '/company-os/operations/search?type=ticket&limit=10', 200, true],
    ['finance', '/company-os/requests?limit=10', 200, true],
    ['finance', '/company-os/operations/search?type=request&limit=10', 200, true],
    ['manager', '/company-os/requests?limit=10', 200, true],
    ['manager', '/company-os/operations/search?type=ticket&limit=10', 200, true],
    ['admin', '/company-os/operations/audit?limit=10', 200, true],
    ['admin', '/company-os/organization/employees?limit=10', 200, true],
    ['super_admin', '/company-os/licenses?limit=10', 200, true],
    ['out_of_scope', '/company-os/tickets?scope=self&limit=10', 404, false],
  ];
  for (const [alias, path, status, bounded] of listChecks) {
    const result = await requestJson({ fetchImpl, baseUrl, token: actors[alias].token, path, metrics });
    if (bounded) assertBoundedList(result, `${alias} ${path}`);
    else assertResponse(result, status, `${alias} ${path}`);
    evidence.push({ actor: alias, route: path.split('?')[0], status, items: Array.isArray(result.payload.items) ? result.payload.items.length : null });
  }
  return { ok: true, evidence, requestedPageSize: 10, documentedServerReadCeiling: 100, metrics: metricsSummary(metrics) };
}

function operationIdFor(buildId) {
  return `acceptance-ticket-${crypto.createHash('sha256').update(String(buildId)).digest('hex').slice(0, 24)}`;
}

async function verifyLegacyFallbacks({ legacyUrls, fetchImpl = fetch, metrics = createMetrics() }) {
  const checked = [];
  for (const flag of FLAGS) {
    const startedAt = Date.now();
    const response = await fetchImpl(legacyUrls[flag], { method: 'GET', redirect: 'manual' });
    metrics.requests.push({ method: 'GET', route: `legacy:${flag}`, status: response.status, durationMs: Math.max(0, Date.now() - startedAt), safeCode: null, items: 0 });
    if (response.status < 200 || response.status >= 400) throw acceptanceError(`Legacy fallback for ${flag} returned HTTP ${response.status}.`);
    checked.push(flag);
  }
  return { ok: true, checked, metrics: metricsSummary(metrics) };
}

async function runPilot({ baseUrl, actors, buildId, allowWrites, legacyUrls, fetchImpl = fetch }) {
  if (allowWrites !== true) throw acceptanceError('Pilot writes require COMPANY_OS_ACCEPTANCE_ALLOW_WRITES=true.');
  if (!legacyUrls) throw acceptanceError('Pilot requires every non-production legacy fallback URL.');
  const metrics = createMetrics();
  const operationId = operationIdFor(buildId);
  const input = {
    operationId,
    subject: 'اختبار قبول Company OS',
    description: 'تذكرة اختبار غير إنتاجية لإثبات منع التكرار.',
    category: 'acceptance_test',
    priority: 'low',
  };
  const first = await requestJson({ fetchImpl, baseUrl, token: actors.employee.token, path: '/company-os/tickets', method: 'POST', body: input, metrics });
  const replay = await requestJson({ fetchImpl, baseUrl, token: actors.employee.token, path: '/company-os/tickets', method: 'POST', body: input, metrics });
  assertResponse(first, 200, 'pilot ticket create');
  assertResponse(replay, 200, 'pilot ticket replay');
  if (!first.payload.resourceId || first.payload.resourceId !== replay.payload.resourceId || first.payload.operationId !== replay.payload.operationId) {
    throw acceptanceError('Pilot retry did not replay the original operation result.');
  }
  const audit = await requestJson({ fetchImpl, baseUrl, token: actors.super_admin.token, path: '/company-os/operations/audit?limit=100', metrics });
  assertBoundedList(audit, 'pilot audit', 100);
  const matching = audit.payload.items.filter((item) => item.operationId === operationId);
  if (matching.length !== 1) throw acceptanceError(`Pilot expected one audit event, received ${matching.length}.`);
  const fallbacks = await verifyLegacyFallbacks({ legacyUrls, fetchImpl, metrics });
  return { ok: true, operationAlias: 'stable_acceptance_ticket', duplicateResources: 0, auditEvents: 1, legacyFallbacks: fallbacks.checked, metrics: metricsSummary(metrics) };
}

async function runRollbackVerification({ baseUrl, actors, fetchImpl = fetch }) {
  const checked = [];
  const metrics = createMetrics();
  for (const alias of ['employee', 'it_manager', 'finance', 'manager', 'admin', 'super_admin']) {
    const result = await requestJson({ fetchImpl, baseUrl, token: actors[alias].token, path: '/company-os/me', metrics });
    assertResponse(result, 200, `${alias} rollback identity`);
    if (FLAGS.some((flag) => result.payload.flags?.[flag] !== false)) throw acceptanceError(`${alias} still has an enabled Company OS flag.`);
    checked.push(alias);
  }
  const fallback = await requestJson({ fetchImpl, baseUrl, token: actors.employee.token, path: '/company-os/tickets?scope=self&limit=10', metrics });
  assertResponse(fallback, 404, 'rollback disabled route');
  return { ok: true, flagsDisabledFor: checked, legacyFallbackRetained: true, metrics: metricsSummary(metrics) };
}

async function main(env = process.env, fetchImpl = fetch) {
  const mode = String(env.COMPANY_OS_ACCEPTANCE_MODE || 'preflight').trim();
  if (!['preflight', 'pilot', 'rollback'].includes(mode)) throw acceptanceError('Unsupported acceptance mode.');
  const baseUrl = validateBaseUrl(env.COMPANY_OS_ACCEPTANCE_BASE_URL);
  const actors = parseActorTokens(env.COMPANY_OS_ACCEPTANCE_TOKENS_JSON);
  const buildId = String(env.COMPANY_OS_ACCEPTANCE_BUILD_ID || '').trim();
  const apiVersion = String(env.COMPANY_OS_ACCEPTANCE_API_VERSION || '').trim();
  if (!buildId || !apiVersion) throw acceptanceError('Build ID and API version are required.');
  const startedAt = new Date().toISOString();
  const result = mode === 'preflight'
    ? await runRoleMatrix({ baseUrl, actors, fetchImpl })
    : mode === 'pilot'
      ? await runPilot({ baseUrl, actors, buildId, allowWrites: env.COMPANY_OS_ACCEPTANCE_ALLOW_WRITES === 'true', legacyUrls: validateLegacyUrls(env.COMPANY_OS_ACCEPTANCE_LEGACY_URLS_JSON), fetchImpl })
      : await runRollbackVerification({ baseUrl, actors, fetchImpl });
  return safeEvidence({ ok: true, environment: 'non-production', mode, buildId, apiVersion, startedAt, completedAt: new Date().toISOString(), result });
}

if (require.main === module) {
  main().then((evidence) => {
    process.stdout.write(`${JSON.stringify(evidence, null, 2)}\n`);
  }).catch((error) => {
    process.stderr.write(`${JSON.stringify({ ok: false, code: 'acceptance_failed', message: String(error?.message || 'Acceptance failed.') })}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  FLAGS, REQUIRED_ACTORS, validateBaseUrl, validateLegacyUrls, parseActorTokens,
  hasForbiddenData, safeEvidence, createMetrics, metricsSummary, requestJson,
  runRoleMatrix, verifyLegacyFallbacks, runPilot, runRollbackVerification,
  operationIdFor, main,
};
