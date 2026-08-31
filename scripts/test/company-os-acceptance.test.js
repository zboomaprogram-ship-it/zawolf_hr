'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  FLAGS, REQUIRED_ACTORS, validateBaseUrl, validateLegacyUrls, parseActorTokens,
  hasForbiddenData, safeEvidence, metricsSummary, runRoleMatrix, runPilot,
  runRollbackVerification, operationIdFor,
} = require('../company-os-acceptance');

function actors() {
  return Object.fromEntries(REQUIRED_ACTORS.map((alias) => [alias, { token: `${alias}-token-value-123456789` }]));
}

function response(status, payload) {
  return { status, async text() { return JSON.stringify(payload); } };
}

function aliasFromHeader(options) {
  return String(options.headers.authorization).replace('Bearer ', '').replace('-token-value-123456789', '');
}

function legacyUrls() {
  return Object.fromEntries(FLAGS.map((flag) => [flag, `https://web-staging.example.test/#/${flag}`]));
}

test('acceptance runner blocks production and unclear hosts', () => {
  assert.throws(() => validateBaseUrl('https://notification.zawolf.ai'), /Production/);
  assert.throws(() => validateBaseUrl('https://api.example.com'), /non-production/);
  assert.equal(validateBaseUrl('https://notification-staging.zawolf.ai/'), 'https://notification-staging.zawolf.ai');
  assert.equal(validateBaseUrl('http://localhost:8080'), 'http://localhost:8080');
});

test('actor configuration requires aliases and never exposes tokens in evidence', () => {
  const raw = Object.fromEntries(REQUIRED_ACTORS.map((alias) => [alias, `${alias}-token-value-123456789`]));
  const parsed = parseActorTokens(JSON.stringify(raw));
  assert.equal(Object.keys(parsed).length, REQUIRED_ACTORS.length);
  assert.throws(() => parseActorTokens('{}'), /Missing acceptance actor aliases/);
  assert.deepEqual(safeEvidence({ actorUid: 'u1', token: 'secret', nested: { email: 'x', role: 'employee' } }), { nested: { role: 'employee' } });
  assert.equal(JSON.stringify(safeEvidence(parsed)).includes('token-value'), false);
});

test('legacy fallback configuration requires every non-production slice URL', () => {
  assert.deepEqual(validateLegacyUrls(JSON.stringify(legacyUrls())), legacyUrls());
  assert.throws(() => validateLegacyUrls(JSON.stringify({})), /Missing legacy fallback URL/);
  assert.throws(() => validateLegacyUrls(JSON.stringify(Object.fromEntries(FLAGS.map((flag) => [flag, 'https://zawolf-hr-system-60317.web.app/'])))), /Production/);
});

test('metrics summarize p95, denials, errors, and bounded item counts', () => {
  assert.deepEqual(metricsSummary({ requests: [
    { durationMs: 10, status: 200, items: 2 },
    { durationMs: 30, status: 403, safeCode: 'access_denied', items: 0 },
    { durationMs: 20, status: 503, safeCode: 'temporary_unavailable', items: 0 },
  ] }), {
    requestCount: 3, p95LatencyMs: 30, deniedScopeAttempts: 1,
    maxReturnedItems: 2,
    safeErrorCounts: { access_denied: 1, temporary_unavailable: 1 },
  });
});

test('provider and private response details are rejected recursively', () => {
  assert.equal(hasForbiddenData({ data: { privateNote: 'hidden' } }), '$.data.privateNote');
  assert.equal(hasForbiddenData({ message: '[cloud_firestore/unavailable]' }), '$.message');
  assert.equal(hasForbiddenData({ data: { title: 'safe' } }), null);
});

test('role matrix verifies audience, authorization, and bounded list requests', async () => {
  const calls = [];
  const role = { employee: 'employee', it_support: 'it_support', it_manager: 'it_manager', finance: 'finance', manager: 'manager', admin: 'hr_admin', super_admin: 'super_admin', out_of_scope: 'employee' };
  const fetchImpl = async (url, options) => {
    const alias = aliasFromHeader(options);
    calls.push({ alias, url });
    if (url.endsWith('/company-os/me')) {
      if (alias === 'inactive') return response(403, { ok: false, safeCode: 'access_denied' });
      return response(200, { ok: true, actor: { role: role[alias] }, flags: Object.fromEntries(FLAGS.map((flag) => [flag, alias !== 'out_of_scope'])) });
    }
    if (alias === 'out_of_scope') return response(404, { ok: false, code: 'feature_disabled' });
    const denied = (alias === 'employee' && (url.includes('/assets') || url.includes('/operations/')))
      || (alias === 'it_support' && url.includes('/operations/'));
    return denied ? response(403, { ok: false, safeCode: 'access_denied' })
      : response(200, { ok: true, items: [{ id: 'safe' }], appliedScope: alias });
  };
  const result = await runRoleMatrix({ baseUrl: 'https://api-staging.example.test', actors: actors(), fetchImpl });
  assert.equal(result.ok, true);
  assert.equal(result.requestedPageSize, 10);
  assert.equal(result.metrics.requestCount, calls.length);
  assert.equal(result.metrics.deniedScopeAttempts, 4);
  assert.ok(calls.filter((call) => call.url.includes('limit=10')).length >= 10);
  assert.equal(JSON.stringify(result).includes('token-value'), false);
});

test('pilot reuses one operation ID and requires exactly one audit event', async () => {
  const seenBodies = [];
  const buildId = 'build-005-test';
  const operationId = operationIdFor(buildId);
  const fetchImpl = async (url, options = {}) => {
    if (url.includes('/#/')) return response(200, {});
    if (options.method === 'POST') {
      seenBodies.push(JSON.parse(options.body));
      return response(200, { ok: true, operationId, resourceId: 'ticket-safe', status: 'saved' });
    }
    return response(200, { ok: true, items: [{ operationId, action: 'ticket_create' }] });
  };
  await assert.rejects(runPilot({ baseUrl: 'https://api-staging.example.test', actors: actors(), buildId, allowWrites: false, legacyUrls: legacyUrls(), fetchImpl }), /ALLOW_WRITES/);
  const result = await runPilot({ baseUrl: 'https://api-staging.example.test', actors: actors(), buildId, allowWrites: true, legacyUrls: legacyUrls(), fetchImpl });
  assert.equal(result.auditEvents, 1);
  assert.equal(result.legacyFallbacks.length, FLAGS.length);
  assert.equal(result.metrics.requestCount, 3 + FLAGS.length);
  assert.equal(seenBodies.length, 2);
  assert.equal(seenBodies[0].operationId, seenBodies[1].operationId);
});

test('rollback verification requires disabled flags and a disabled route', async () => {
  const fetchImpl = async (url) => url.endsWith('/company-os/me')
    ? response(200, { ok: true, actor: { role: 'employee' }, flags: Object.fromEntries(FLAGS.map((flag) => [flag, false])) })
    : response(404, { ok: false, code: 'feature_disabled' });
  const result = await runRollbackVerification({ baseUrl: 'https://api-staging.example.test', actors: actors(), fetchImpl });
  assert.equal(result.legacyFallbackRetained, true);
});
