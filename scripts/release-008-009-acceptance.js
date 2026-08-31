'use strict';

const fs = require('node:fs');
const crypto = require('node:crypto');

const {
  validateBaseUrl,
  requestJson,
  createMetrics,
  metricsSummary,
  safeEvidence,
} = require('./company-os-acceptance');
const {
  buildMultiTreeMigrationPlan,
  DEFAULT_TREE_ID,
} = require('./company-os/migrate-organization-trees');
const {
  buildAttendanceLocationMigrationPlan,
} = require('./migrate-attendance-locations');

const REQUIRED_ACTORS = Object.freeze([
  'employee',
  'manager',
  'tree_admin',
  'hr',
  'admin',
  'super_admin',
  'inactive',
  'out_of_scope',
]);

const EXPECTED_ROLES = Object.freeze({
  employee: ['employee'],
  manager: ['manager'],
  tree_admin: ['employee', 'manager', 'hr', 'hr_admin', 'admin'],
  hr: ['hr', 'hr_admin'],
  admin: ['admin'],
  super_admin: ['super_admin'],
  out_of_scope: ['employee'],
});

const PILOT_BOOLEAN_PATHS = Object.freeze([
  'organization.secondaryTreeVisible',
  'organization.primaryRoutingPassed',
  'organization.immutableExistingApprovalPlanPassed',
  'organization.rollbackTestPassed',
  'attendance.manualCheckInPassed',
  'attendance.offlineQueuePassed',
  'attendance.automaticEntryPassed',
  'attendance.duplicateConvergencePassed',
  'attendance.staleAssignmentRejected',
  'attendance.inactiveSiteRejected',
  'attendance.outsideRangeRejected',
  'attendance.rollbackTestPassed',
]);

function acceptanceError(message) {
  const error = new Error(message);
  error.code = 'acceptance_failed';
  return error;
}

function parseJson(value, label) {
  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value;
    if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') {
      throw new Error('not an object');
    }
    return parsed;
  } catch (_) {
    throw acceptanceError(`${label} must be a JSON object.`);
  }
}

function parseActorTokens(value) {
  const input = parseJson(value, 'ZAWOLF_008_009_ACCEPTANCE_TOKENS_JSON');
  const missing = REQUIRED_ACTORS.filter((alias) => !input[alias]);
  if (missing.length) {
    throw acceptanceError(`Missing acceptance actor aliases: ${missing.join(', ')}.`);
  }
  return Object.fromEntries(REQUIRED_ACTORS.map((alias) => {
    const raw = input[alias];
    const token = typeof raw === 'string' ? raw : raw?.token;
    if (typeof token !== 'string' || token.trim().length < 16) {
      throw acceptanceError(`Invalid token for actor alias ${alias}.`);
    }
    return [alias, { token: token.trim() }];
  }));
}

function nestedValue(value, path) {
  return path.split('.').reduce((current, key) => current?.[key], value);
}

function containsPersonalData(value, key = '') {
  if (Array.isArray(value)) return value.some((item) => containsPersonalData(item, key));
  if (value && typeof value === 'object') {
    return Object.entries(value).some(([childKey, child]) => {
      if (/^(?:email|phone|mobile|nationalId|fullName|displayName|name)$/i.test(childKey)) {
        return String(child || '').trim().length > 0;
      }
      return containsPersonalData(child, childKey);
    });
  }
  return typeof value === 'string' && (value.includes('@') || /\+?[0-9][0-9\s-]{8,}/.test(value));
}

function validateSanitizedFixture(value) {
  const fixture = parseJson(value, 'Migration fixture');
  if (fixture.sanitized !== true) {
    throw acceptanceError('Migration fixture must explicitly set sanitized=true.');
  }
  if (!/(?:staging|stage|test|testing|nonprod|non-production|emulator)/i.test(String(fixture.environment || ''))) {
    throw acceptanceError('Migration fixture must identify a non-production environment.');
  }
  if (containsPersonalData(fixture)) {
    throw acceptanceError('Migration fixture contains personal data; use aliases only.');
  }
  for (const section of ['organization', 'attendance']) {
    if (!fixture[section] || typeof fixture[section] !== 'object') {
      throw acceptanceError(`Migration fixture is missing ${section}.`);
    }
  }
  return fixture;
}

function assertUniqueWrites(writes, label) {
  const ids = writes.map((write) => String(write.id));
  if (new Set(ids).size !== ids.length) {
    throw acceptanceError(`${label} contains duplicate write IDs.`);
  }
}

function runMigrationRehearsal(rawFixture) {
  const fixture = validateSanitizedFixture(rawFixture);
  const organizationInput = {
    units: fixture.organization.units || [],
    users: fixture.organization.users || [],
    existingTrees: fixture.organization.existingTrees || [],
    existingMemberships: fixture.organization.existingMemberships || [],
  };
  const attendanceInput = {
    users: fixture.attendance.users || [],
    existingAssignments: fixture.attendance.existingAssignments || [],
  };
  const organizationPlan = buildMultiTreeMigrationPlan(organizationInput);
  const attendancePlan = buildAttendanceLocationMigrationPlan(attendanceInput);

  assertUniqueWrites(organizationPlan.unitWrites, 'Organization unit plan');
  assertUniqueWrites(organizationPlan.membershipWrites, 'Organization membership plan');
  assertUniqueWrites(organizationPlan.userWrites, 'Organization user plan');
  assertUniqueWrites(attendancePlan.writes, 'Attendance assignment plan');
  if (organizationPlan.rollback?.destructiveWrites !== 0 || attendancePlan.rollback?.destructiveWrites !== 0) {
    throw acceptanceError('A migration rollback contains destructive writes.');
  }

  const secondOrganizationPlan = buildMultiTreeMigrationPlan({
    units: organizationInput.units.map((unit) => ({ ...unit, treeId: unit.treeId || DEFAULT_TREE_ID })),
    users: organizationInput.users.map((user) => {
      const uid = String(user.uid || user.id || '').trim();
      const unitId = String(user.departmentUnitId || user.departmentId || '').trim();
      const membershipId = uid && unitId ? `${DEFAULT_TREE_ID}_${uid}_${unitId}` : null;
      return membershipId ? {
        ...user,
        primaryOrganizationTreeId: DEFAULT_TREE_ID,
        primaryOrganizationMembershipId: membershipId,
      } : user;
    }),
    existingTrees: [
      ...organizationInput.existingTrees,
      ...(organizationPlan.treeWrite ? [{ id: organizationPlan.treeWrite.id, ...organizationPlan.treeWrite.value }] : []),
    ],
    existingMemberships: [
      ...organizationInput.existingMemberships,
      ...organizationPlan.membershipWrites.map((write) => ({ id: write.id, ...write.value })),
    ],
  });
  const secondAttendancePlan = buildAttendanceLocationMigrationPlan({
    users: attendanceInput.users,
    existingAssignments: [
      ...attendanceInput.existingAssignments,
      ...attendancePlan.writes.map((write) => ({ id: write.id, ...write.value })),
    ],
  });
  const secondOrganizationSummary = secondOrganizationPlan.summary;
  const secondAttendanceSummary = secondAttendancePlan.summary;
  if (Object.values(secondOrganizationSummary).some((count) => count !== 0) || secondAttendanceSummary.assignments !== 0) {
    throw acceptanceError('Migration rehearsal is not idempotent after simulated apply.');
  }

  return {
    ok: true,
    environment: String(fixture.environment),
    organization: {
      firstSummary: organizationPlan.summary,
      secondSummary: secondOrganizationSummary,
      fingerprint: organizationPlan.fingerprint,
      rollback: organizationPlan.rollback,
    },
    attendance: {
      firstSummary: attendancePlan.summary,
      secondSummary: secondAttendanceSummary,
      fingerprint: attendancePlan.fingerprint,
      rollback: attendancePlan.rollback,
    },
  };
}

function assertStatus(result, expected, label) {
  const expectedStatuses = Array.isArray(expected) ? expected : [expected];
  if (!expectedStatuses.includes(result.status)) {
    throw acceptanceError(`${label} expected HTTP ${expectedStatuses.join('/')}, received ${result.status} (${result.payload?.code || result.payload?.safeCode || 'unknown'}).`);
  }
  if (result.status === 200 && result.payload?.ok !== true) {
    throw acceptanceError(`${label} did not return ok=true.`);
  }
}

async function runAuthorizationMatrix({
  baseUrl,
  actors,
  treeId,
  targetEmployeeUid,
  fetchImpl = fetch,
}) {
  if (!/^[A-Za-z0-9_.:-]{1,128}$/.test(String(treeId || ''))) {
    throw acceptanceError('A safe staging tree ID is required.');
  }
  if (!String(targetEmployeeUid || '').trim()) {
    throw acceptanceError('A staging target employee UID is required.');
  }
  const metrics = createMetrics();
  const evidence = [];
  let successfulMutations = 0;
  for (const alias of REQUIRED_ACTORS) {
    const result = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: '/company-os/me',
      metrics,
    });
    if (alias === 'inactive') {
      assertStatus(result, 403, 'inactive identity');
      evidence.push({ actor: alias, identityStatus: 403 });
      continue;
    }
    assertStatus(result, 200, `${alias} identity`);
    const role = String(result.payload.actor?.role || '');
    if (!EXPECTED_ROLES[alias].includes(role)) {
      throw acceptanceError(`${alias} resolved to unexpected role ${role || 'empty'}.`);
    }
    const enabled = result.payload.flags?.company_os_multi_tree_v1 === true;
    if (alias === 'out_of_scope' ? enabled : !enabled) {
      throw acceptanceError(`${alias} has an incorrect company_os_multi_tree_v1 audience result.`);
    }
    evidence.push({ actor: alias, identityStatus: 200, role, multiTreeEnabled: enabled });
  }

  for (const alias of ['employee', 'manager', 'tree_admin', 'hr', 'admin', 'super_admin']) {
    const result = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: '/company-os/organization/trees?limit=10',
      metrics,
    });
    assertStatus(result, 200, `${alias} tree list`);
    if (!Array.isArray(result.payload.items) || result.payload.items.length > 10) {
      throw acceptanceError(`${alias} tree list is not bounded.`);
    }
  }
  const outOfScopeTrees = await requestJson({
    fetchImpl,
    baseUrl,
    token: actors.out_of_scope.token,
    path: '/company-os/organization/trees?limit=10',
    metrics,
  });
  assertStatus(outOfScopeTrees, 404, 'out-of-scope tree list');

  for (const alias of ['employee', 'manager', 'tree_admin', 'hr', 'admin', 'super_admin']) {
    const snapshot = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: `/company-os/organization/trees/${encodeURIComponent(treeId)}/snapshot?limit=100`,
      metrics,
    });
    assertStatus(snapshot, ['tree_admin', 'hr', 'admin', 'super_admin'].includes(alias) ? 200 : 403, `${alias} tree snapshot`);
  }

  for (const alias of ['employee', 'manager', 'tree_admin', 'hr', 'admin', 'super_admin']) {
    const mutationProbe = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: '/company-os/organization/trees',
      method: 'POST',
      body: {},
      metrics,
    });
    if (mutationProbe.status >= 200 && mutationProbe.status < 300) successfulMutations += 1;
    assertStatus(mutationProbe, ['hr', 'admin', 'super_admin'].includes(alias) ? 400 : 403, `${alias} global tree mutation probe`);
  }

  const ownAssignments = await requestJson({
    fetchImpl,
    baseUrl,
    token: actors.employee.token,
    path: '/attendance/locations/assignments/me',
    metrics,
  });
  assertStatus(ownAssignments, 200, 'employee own attendance assignments');
  if (ownAssignments.payload.enabled !== true) {
    throw acceptanceError('attendance_multi_location_v1 is not enabled for the staging employee.');
  }

  for (const alias of ['manager', 'tree_admin', 'hr', 'admin', 'super_admin']) {
    const list = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: `/attendance/locations/assignments?employeeUid=${encodeURIComponent(targetEmployeeUid)}&limit=20`,
      metrics,
    });
    assertStatus(list, ['hr', 'admin', 'super_admin'].includes(alias) ? 200 : 403, `${alias} attendance assignment list`);
  }
  for (const alias of ['employee', 'manager', 'tree_admin', 'hr', 'admin', 'super_admin']) {
    const previewProbe = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: '/attendance/locations/assignments/preview',
      method: 'POST',
      body: {},
      metrics,
    });
    if (previewProbe.status >= 200 && previewProbe.status < 300) successfulMutations += 1;
    assertStatus(previewProbe, ['hr', 'admin', 'super_admin'].includes(alias) ? 400 : 403, `${alias} attendance mutation probe`);
  }
  if (successfulMutations !== 0) {
    throw acceptanceError('The read-only role matrix unexpectedly committed a mutation.');
  }
  return {
    ok: true,
    evidence,
    unauthorizedSuccesses: 0,
    writeCount: 0,
    metrics: metricsSummary(metrics),
  };
}

function validatePilotObservations(raw, {
  maxP95LatencyMs = 2500,
  maxReadsPerCheckIn = 8,
} = {}) {
  const observations = parseJson(raw, 'Pilot observations');
  if (observations.sanitized !== true) {
    throw acceptanceError('Pilot observations must explicitly set sanitized=true.');
  }
  if (containsPersonalData(observations)) {
    throw acceptanceError('Pilot observations contain personal data; use aliases only.');
  }
  for (const path of PILOT_BOOLEAN_PATHS) {
    if (nestedValue(observations, path) !== true) {
      throw acceptanceError(`Pilot observation ${path} must be true.`);
    }
  }
  if (Number(observations.organization?.unauthorizedAccessCount) !== 0) {
    throw acceptanceError('Pilot contains an unauthorized organization access.');
  }
  if (Number(observations.organization?.auditEventCount) < 1) {
    throw acceptanceError('Pilot must verify at least one organization audit event.');
  }
  const attendance = observations.attendance || {};
  if (Number(attendance.employeeAliasCount) < 2) {
    throw acceptanceError('Pilot must include at least two aliased employees.');
  }
  if (!Array.isArray(attendance.deviceAliases) || new Set(attendance.deviceAliases).size < 2) {
    throw acceptanceError('Pilot must include two real devices represented by safe aliases.');
  }
  if (!Array.isArray(attendance.locationAliases) || new Set(attendance.locationAliases).size < 2) {
    throw acceptanceError('Pilot must include two real attendance locations represented by safe aliases.');
  }
  if (Number(attendance.duplicateCount) !== 0) {
    throw acceptanceError('Pilot produced a duplicate attendance record.');
  }
  if (Number(attendance.auditEventCount) < 1) {
    throw acceptanceError('Pilot must verify attendance audit events.');
  }
  if (!Number.isFinite(Number(attendance.p95LatencyMs)) || Number(attendance.p95LatencyMs) > maxP95LatencyMs) {
    throw acceptanceError('Pilot attendance p95 latency exceeds the approved threshold.');
  }
  if (!Number.isFinite(Number(attendance.maxFirestoreReadsPerCheckIn)) || Number(attendance.maxFirestoreReadsPerCheckIn) > maxReadsPerCheckIn) {
    throw acceptanceError('Pilot Firestore reads per check-in exceed the approved threshold.');
  }
  return observations;
}

async function runPilotVerification({
  baseUrl,
  actors,
  treeId,
  expectedLocationIds,
  observations,
  maxP95LatencyMs = 2500,
  maxReadsPerCheckIn = 8,
  fetchImpl = fetch,
}) {
  const safeObservations = validatePilotObservations(observations, {
    maxP95LatencyMs,
    maxReadsPerCheckIn,
  });
  if (!Array.isArray(expectedLocationIds) || new Set(expectedLocationIds.map(String)).size < 2) {
    throw acceptanceError('Two staging location IDs are required for pilot verification.');
  }
  const metrics = createMetrics();
  const trees = await requestJson({
    fetchImpl,
    baseUrl,
    token: actors.admin.token,
    path: '/company-os/organization/trees?limit=100&includeArchived=true',
    metrics,
  });
  assertStatus(trees, 200, 'pilot tree list');
  if (!Array.isArray(trees.payload.items) || !trees.payload.items.some((tree) => String(tree.id) === String(treeId))) {
    throw acceptanceError('The configured secondary pilot tree is not visible remotely.');
  }
  const snapshot = await requestJson({
    fetchImpl,
    baseUrl,
    token: actors.tree_admin.token,
    path: `/company-os/organization/trees/${encodeURIComponent(treeId)}/snapshot?limit=500`,
    metrics,
  });
  assertStatus(snapshot, 200, 'pilot tree-admin snapshot');
  if (String(snapshot.payload.data?.tree?.id || '') !== String(treeId)) {
    throw acceptanceError('The tree-admin snapshot returned a different tree.');
  }
  const assignments = await requestJson({
    fetchImpl,
    baseUrl,
    token: actors.employee.token,
    path: '/attendance/locations/assignments/me',
    metrics,
  });
  assertStatus(assignments, 200, 'pilot employee assignments');
  if (assignments.payload.enabled !== true) {
    throw acceptanceError('Multi-location attendance is not enabled for the pilot employee.');
  }
  const activeIds = new Set((assignments.payload.assignments || [])
    .filter((item) => item.isActive === true && item.locationIsActive !== false)
    .map((item) => String(item.locationId)));
  if (!expectedLocationIds.every((id) => activeIds.has(String(id)))) {
    throw acceptanceError('The pilot employee does not have both expected active locations.');
  }
  return safeEvidence({
    ok: true,
    secondaryTreeVerified: true,
    activeAssignmentCount: activeIds.size,
    observations: safeObservations,
    metrics: metricsSummary(metrics),
  });
}

async function runRollbackVerification({ baseUrl, actors, fetchImpl = fetch }) {
  const metrics = createMetrics();
  for (const alias of ['employee', 'manager', 'tree_admin', 'hr', 'admin', 'super_admin']) {
    const identity = await requestJson({
      fetchImpl,
      baseUrl,
      token: actors[alias].token,
      path: '/company-os/me',
      metrics,
    });
    assertStatus(identity, 200, `${alias} rollback identity`);
    if (identity.payload.flags?.company_os_multi_tree_v1 !== false) {
      throw acceptanceError(`company_os_multi_tree_v1 remains enabled for ${alias}.`);
    }
  }
  const attendance = await requestJson({
    fetchImpl,
    baseUrl,
    token: actors.employee.token,
    path: '/attendance/locations/assignments/me',
    metrics,
  });
  assertStatus(attendance, 200, 'attendance rollback identity');
  if (attendance.payload.enabled !== false) {
    throw acceptanceError('attendance_multi_location_v1 remains enabled for the pilot employee.');
  }
  return { ok: true, flagsDisabled: true, destructiveWrites: 0, metrics: metricsSummary(metrics) };
}

function readJsonFile(path, label) {
  const safePath = String(path || '').trim();
  if (!safePath) throw acceptanceError(`${label} path is required.`);
  try {
    return JSON.parse(fs.readFileSync(safePath, 'utf8'));
  } catch (error) {
    throw acceptanceError(`Unable to read ${label}: ${error.message}`);
  }
}

function evidenceId({ mode, buildId, startedAt }) {
  return crypto.createHash('sha256')
    .update(`${mode}:${buildId}:${startedAt}`)
    .digest('hex');
}

async function main(env = process.env, fetchImpl = fetch) {
  const mode = String(env.ZAWOLF_008_009_ACCEPTANCE_MODE || 'migration').trim();
  if (!['migration', 'matrix', 'pilot', 'rollback'].includes(mode)) {
    throw acceptanceError('Unsupported 008/009 acceptance mode.');
  }
  const buildId = String(env.ZAWOLF_008_009_ACCEPTANCE_BUILD_ID || '').trim();
  if (!buildId) throw acceptanceError('ZAWOLF_008_009_ACCEPTANCE_BUILD_ID is required.');
  const startedAt = new Date().toISOString();
  let result;
  if (mode === 'migration') {
    result = runMigrationRehearsal(readJsonFile(
      env.ZAWOLF_008_009_MIGRATION_FIXTURE,
      'sanitized migration fixture',
    ));
  } else {
    const baseUrl = validateBaseUrl(env.ZAWOLF_008_009_ACCEPTANCE_BASE_URL);
    const actors = parseActorTokens(env.ZAWOLF_008_009_ACCEPTANCE_TOKENS_JSON);
    if (mode === 'matrix') {
      result = await runAuthorizationMatrix({
        baseUrl,
        actors,
        treeId: env.ZAWOLF_008_009_TREE_ID,
        targetEmployeeUid: env.ZAWOLF_008_009_TARGET_EMPLOYEE_UID,
        fetchImpl,
      });
    } else if (mode === 'pilot') {
      if (env.ZAWOLF_008_009_ACCEPTANCE_ALLOW_PILOT !== 'true') {
        throw acceptanceError('Pilot verification requires ZAWOLF_008_009_ACCEPTANCE_ALLOW_PILOT=true.');
      }
      result = await runPilotVerification({
        baseUrl,
        actors,
        treeId: env.ZAWOLF_008_009_TREE_ID,
        expectedLocationIds: String(env.ZAWOLF_008_009_LOCATION_IDS || '')
          .split(',').map((value) => value.trim()).filter(Boolean),
        observations: readJsonFile(env.ZAWOLF_008_009_PILOT_OBSERVATIONS, 'pilot observations'),
        maxP95LatencyMs: Number(env.ZAWOLF_008_009_MAX_P95_MS || 2500),
        maxReadsPerCheckIn: Number(env.ZAWOLF_008_009_MAX_READS_PER_CHECK_IN || 8),
        fetchImpl,
      });
    } else {
      result = await runRollbackVerification({ baseUrl, actors, fetchImpl });
    }
  }
  const completedAt = new Date().toISOString();
  return safeEvidence({
    ok: true,
    evidenceId: evidenceId({ mode, buildId, startedAt }),
    environment: 'non-production',
    mode,
    buildId,
    startedAt,
    completedAt,
    result,
  });
}

if (require.main === module) {
  main().then((evidence) => {
    process.stdout.write(`${JSON.stringify(evidence, null, 2)}\n`);
  }).catch((error) => {
    process.stderr.write(`${JSON.stringify({
      ok: false,
      code: 'acceptance_failed',
      message: String(error?.message || 'Acceptance failed.'),
    })}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  REQUIRED_ACTORS,
  parseActorTokens,
  validateSanitizedFixture,
  runMigrationRehearsal,
  runAuthorizationMatrix,
  validatePilotObservations,
  runPilotVerification,
  runRollbackVerification,
  evidenceId,
  main,
};
