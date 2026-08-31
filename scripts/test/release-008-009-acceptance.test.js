'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  REQUIRED_ACTORS,
  parseActorTokens,
  validateSanitizedFixture,
  runMigrationRehearsal,
  runAuthorizationMatrix,
  validatePilotObservations,
  runPilotVerification,
  runRollbackVerification,
} = require('../release-008-009-acceptance');

function actors() {
  return Object.fromEntries(REQUIRED_ACTORS.map((alias) => [
    alias,
    { token: `${alias}-token-value-123456789` },
  ]));
}

function response(status, payload) {
  return { status, async text() { return JSON.stringify(payload); } };
}

function aliasFromHeader(options = {}) {
  return String(options.headers?.authorization || '')
    .replace('Bearer ', '')
    .replace('-token-value-123456789', '');
}

function sanitizedFixture() {
  return {
    environment: 'staging',
    sanitized: true,
    organization: {
      units: [{ id: 'unit-test-a' }],
      users: [{ uid: 'employee-test-a', departmentUnitId: 'unit-test-a' }],
      existingTrees: [],
      existingMemberships: [],
    },
    attendance: {
      users: [{ uid: 'employee-test-a', locationId: 'location-test-a' }],
      existingAssignments: [],
    },
  };
}

function pilotObservations() {
  return {
    sanitized: true,
    organization: {
      secondaryTreeVisible: true,
      primaryRoutingPassed: true,
      immutableExistingApprovalPlanPassed: true,
      unauthorizedAccessCount: 0,
      auditEventCount: 1,
      rollbackTestPassed: true,
    },
    attendance: {
      employeeAliasCount: 2,
      deviceAliases: ['device-a', 'device-b'],
      locationAliases: ['site-a', 'site-b'],
      manualCheckInPassed: true,
      offlineQueuePassed: true,
      automaticEntryPassed: true,
      duplicateConvergencePassed: true,
      staleAssignmentRejected: true,
      inactiveSiteRejected: true,
      outsideRangeRejected: true,
      duplicateCount: 0,
      auditEventCount: 2,
      rollbackTestPassed: true,
      p95LatencyMs: 900,
      maxFirestoreReadsPerCheckIn: 5,
    },
  };
}

test('acceptance actor configuration requires every 008/009 runtime role', () => {
  const raw = Object.fromEntries(REQUIRED_ACTORS.map((alias) => [
    alias,
    `${alias}-token-value-123456789`,
  ]));
  const parsed = parseActorTokens(JSON.stringify(raw));
  assert.deepEqual(Object.keys(parsed), REQUIRED_ACTORS);
  assert.throws(() => parseActorTokens('{}'), /Missing acceptance actor aliases/);
  assert.equal(JSON.stringify(parsed).includes('token-value'), true);
});

test('migration rehearsal only accepts explicitly sanitized non-production fixtures', () => {
  assert.doesNotThrow(() => validateSanitizedFixture(sanitizedFixture()));
  assert.throws(() => validateSanitizedFixture({ ...sanitizedFixture(), sanitized: false }), /sanitized=true/);
  assert.throws(() => validateSanitizedFixture({ ...sanitizedFixture(), environment: 'production' }), /non-production/);
  const fixture = sanitizedFixture();
  fixture.organization.users[0].email = 'real@example.com';
  assert.throws(() => validateSanitizedFixture(fixture), /personal data/);
});

test('migration rehearsal proves deterministic plans, idempotency, and non-destructive rollback', () => {
  const result = runMigrationRehearsal(sanitizedFixture());
  assert.equal(result.ok, true);
  assert.deepEqual(result.organization.firstSummary, {
    trees: 1, units: 1, memberships: 1, users: 1,
  });
  assert.deepEqual(result.organization.secondSummary, {
    trees: 0, units: 0, memberships: 0, users: 0,
  });
  assert.deepEqual(result.attendance.firstSummary, { assignments: 1 });
  assert.deepEqual(result.attendance.secondSummary, { assignments: 0 });
  assert.equal(result.organization.rollback.destructiveWrites, 0);
  assert.equal(result.attendance.rollback.destructiveWrites, 0);
});

test('20-tree and 500-employee acceptance fixture stays deterministic and bounded', () => {
  const fixture = sanitizedFixture();
  fixture.organization.existingTrees = Array.from({ length: 19 }, (_, index) => ({
    id: `tree-test-${index + 1}`,
    status: 'active',
  }));
  fixture.organization.units = Array.from({ length: 20 }, (_, index) => ({
    id: `unit-test-${index + 1}`,
    treeId: index === 0 ? undefined : `tree-test-${index}`,
  }));
  fixture.organization.users = Array.from({ length: 500 }, (_, index) => ({
    uid: `employee-test-${index + 1}`,
    departmentUnitId: `unit-test-${(index % 20) + 1}`,
  }));
  fixture.attendance.users = fixture.organization.users.map((user, index) => ({
    uid: user.uid,
    locationId: `location-test-${(index % 4) + 1}`,
  }));

  const startedAt = process.hrtime.bigint();
  const result = runMigrationRehearsal(fixture);
  const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1e6;

  assert.equal(result.ok, true);
  assert.equal(result.organization.firstSummary.users, 500);
  assert.equal(result.organization.secondSummary.users, 0);
  assert.equal(result.attendance.firstSummary.assignments, 500);
  assert.equal(result.attendance.secondSummary.assignments, 0);
  assert.ok(elapsedMs < 10_000, `acceptance fixture took ${elapsedMs}ms`);
});

test('real role matrix checks multi-tree scope and attendance administration without writes', async () => {
  const calls = [];
  const roles = {
    employee: 'employee', manager: 'manager', tree_admin: 'employee',
    hr: 'hr', admin: 'admin', super_admin: 'super_admin',
    out_of_scope: 'employee',
  };
  const fetchImpl = async (url, options = {}) => {
    const alias = aliasFromHeader(options);
    const path = new URL(url).pathname;
    calls.push({ alias, path, method: options.method || 'GET' });
    if (path === '/company-os/me') {
      if (alias === 'inactive') return response(403, { ok: false, code: 'access_denied' });
      return response(200, {
        ok: true,
        actor: { role: roles[alias] },
        flags: { company_os_multi_tree_v1: alias !== 'out_of_scope' },
      });
    }
    if (alias === 'out_of_scope' && path.startsWith('/company-os/')) {
      return response(404, { ok: false, code: 'feature_disabled' });
    }
    if (path === '/company-os/organization/trees') {
      if ((options.method || 'GET') === 'POST') {
        return ['hr', 'admin', 'super_admin'].includes(alias)
          ? response(400, { ok: false, code: 'invalid_input' })
          : response(403, { ok: false, code: 'access_denied' });
      }
      return response(200, { ok: true, items: [{ id: 'tree-test' }] });
    }
    if (path.endsWith('/snapshot')) {
      return ['tree_admin', 'hr', 'admin', 'super_admin'].includes(alias)
        ? response(200, { ok: true, data: { tree: { id: 'tree-test' }, units: [], memberships: [] } })
        : response(403, { ok: false, code: 'access_denied' });
    }
    if (path === '/attendance/locations/assignments/me') {
      return response(200, { ok: true, enabled: true, assignments: [] });
    }
    if (path === '/attendance/locations/assignments') {
      return ['hr', 'admin', 'super_admin'].includes(alias)
        ? response(200, { ok: true, assignments: [] })
        : response(403, { ok: false, code: 'not_authorized' });
    }
    if (path === '/attendance/locations/assignments/preview') {
      return ['hr', 'admin', 'super_admin'].includes(alias)
        ? response(400, { ok: false, code: 'invalid_request' })
        : response(403, { ok: false, code: 'not_authorized' });
    }
    throw new Error(`Unexpected URL ${url}`);
  };

  const result = await runAuthorizationMatrix({
    baseUrl: 'https://notification-staging.example.test',
    actors: actors(),
    treeId: 'tree-test',
    targetEmployeeUid: 'employee-test-a',
    fetchImpl,
  });
  assert.equal(result.ok, true);
  assert.equal(result.unauthorizedSuccesses, 0);
  assert.equal(result.writeCount, 0);
  assert.ok(calls.some((call) => call.alias === 'tree_admin' && call.path.endsWith('/snapshot')));
  assert.ok(calls.some((call) => call.alias === 'hr' && call.path.includes('/attendance/locations/assignments')));
});

test('pilot observations require two employees, devices, locations, all rejection cases, and bounded metrics', () => {
  assert.doesNotThrow(() => validatePilotObservations(pilotObservations(), { maxP95LatencyMs: 2500, maxReadsPerCheckIn: 8 }));
  assert.throws(() => validatePilotObservations({
    ...pilotObservations(),
    attendance: { ...pilotObservations().attendance, deviceAliases: ['only-one'] },
  }), /two real devices/);
  assert.throws(() => validatePilotObservations({
    ...pilotObservations(),
    attendance: { ...pilotObservations().attendance, duplicateCount: 1 },
  }), /duplicate/);
  assert.throws(() => validatePilotObservations({
    ...pilotObservations(),
    attendance: { ...pilotObservations().attendance, p95LatencyMs: 3000 },
  }, { maxP95LatencyMs: 2500, maxReadsPerCheckIn: 8 }), /latency/);
});

test('pilot verification cross-checks the secondary tree and two active remote assignments', async () => {
  const fetchImpl = async (url, options = {}) => {
    const path = new URL(url).pathname;
    const alias = aliasFromHeader(options);
    if (path === '/company-os/organization/trees') {
      return response(200, { ok: true, items: [{ id: 'secondary-tree' }] });
    }
    if (path.endsWith('/snapshot')) {
      return response(200, { ok: true, data: { tree: { id: 'secondary-tree' }, units: [], memberships: [{ isPrimary: false }] } });
    }
    if (path === '/attendance/locations/assignments/me' && alias === 'employee') {
      return response(200, { ok: true, enabled: true, assignments: [
        { id: 'assignment-a', locationId: 'location-a', isActive: true },
        { id: 'assignment-b', locationId: 'location-b', isActive: true },
      ] });
    }
    throw new Error(`Unexpected URL ${url}`);
  };
  const result = await runPilotVerification({
    baseUrl: 'https://notification-staging.example.test',
    actors: actors(),
    treeId: 'secondary-tree',
    expectedLocationIds: ['location-a', 'location-b'],
    observations: pilotObservations(),
    fetchImpl,
  });
  assert.equal(result.ok, true);
  assert.equal(result.secondaryTreeVerified, true);
  assert.equal(result.activeAssignmentCount, 2);
  assert.equal(JSON.stringify(result).includes('location-a'), false);
});

test('rollback verification requires both slices disabled', async () => {
  const fetchImpl = async (url) => {
    const path = new URL(url).pathname;
    if (path === '/company-os/me') {
      return response(200, { ok: true, flags: { company_os_multi_tree_v1: false } });
    }
    if (path === '/attendance/locations/assignments/me') {
      return response(200, { ok: true, enabled: false, assignments: [] });
    }
    throw new Error(`Unexpected URL ${url}`);
  };
  const result = await runRollbackVerification({
    baseUrl: 'https://notification-staging.example.test',
    actors: actors(),
    fetchImpl,
  });
  assert.equal(result.ok, true);
  assert.equal(result.flagsDisabled, true);
});
