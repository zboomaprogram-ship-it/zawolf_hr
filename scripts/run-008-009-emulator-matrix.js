'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const { installFirestoreCompatibility } = require('./firebase-service-account');

const {
  REQUIRED_ACTORS,
  runAuthorizationMatrix,
} = require('./release-008-009-acceptance');

const PROJECT_ID = String(process.env.GCLOUD_PROJECT || '').trim();
const AUTH_HOST = String(process.env.FIREBASE_AUTH_EMULATOR_HOST || '').trim();
const FIRESTORE_HOST = String(process.env.FIRESTORE_EMULATOR_HOST || '').trim();
const PORT = Number(process.env.ZAWOLF_ACCEPTANCE_API_PORT || 43127);
const TREE_ID = 'tree-acceptance-secondary';
const EMPLOYEE_UID = 'acceptance-employee';
const PASSWORD = 'Acceptance-only-2026!';
installFirestoreCompatibility(admin);

function fail(message) {
  throw new Error(message);
}

function requireEmulators() {
  if (!PROJECT_ID || !AUTH_HOST || !FIRESTORE_HOST) {
    fail('Run this script through Firebase emulators:exec with Auth and Firestore.');
  }
  if (![AUTH_HOST, FIRESTORE_HOST].every((host) => /^(?:127\.0\.0\.1|localhost):\d+$/.test(host))) {
    fail('Acceptance emulators must use localhost only.');
  }
  if (PROJECT_ID === 'zawolf-hr-system-60317') {
    fail('Production project id is forbidden for emulator acceptance.');
  }
}

function actorDefinitions() {
  return {
    employee: { uid: EMPLOYEE_UID, role: 'employee', active: true },
    manager: { uid: 'acceptance-manager', role: 'manager', active: true },
    tree_admin: {
      uid: 'acceptance-tree-admin', role: 'employee', active: true,
      organizationTreeAdminIds: [TREE_ID],
    },
    hr: { uid: 'acceptance-hr', role: 'hr', active: true },
    admin: { uid: 'acceptance-admin', role: 'admin', active: true },
    super_admin: { uid: 'acceptance-super-admin', role: 'super_admin', active: true },
    inactive: { uid: 'acceptance-inactive', role: 'employee', active: false },
    out_of_scope: { uid: 'acceptance-out-of-scope', role: 'employee', active: true },
  };
}

async function seedFixture(app) {
  const db = admin.firestore(app);
  const auth = getAuth(app);
  const actors = actorDefinitions();
  const batch = db.batch();
  for (const [alias, actor] of Object.entries(actors)) {
    const email = `${alias.replaceAll('_', '-')}@acceptance.invalid`;
    await auth.createUser({ uid: actor.uid, email, password: PASSWORD });
    batch.set(db.collection('users').doc(actor.uid), {
      role: actor.role,
      operationalRole: actor.role,
      isActive: actor.active,
      organizationTreeAdminIds: actor.organizationTreeAdminIds || [],
      departmentId: 'unit-acceptance',
      employeeId: `ACC-${alias.toUpperCase()}`,
      name: `actor-${alias}`,
    });
  }
  batch.set(db.collection('companyOsOrganizationTrees').doc(TREE_ID), {
    name: 'secondary-acceptance-tree', status: 'active', order: 2, isDefault: false,
  });
  batch.set(db.collection('companyOsOrganizationUnits').doc('unit-acceptance'), {
    treeId: TREE_ID, name: 'acceptance-unit', type: 'department', order: 1,
  });
  batch.set(db.collection('companyOsOrganizationMemberships').doc('membership-acceptance'), {
    treeId: TREE_ID, unitId: 'unit-acceptance', employeeUid: EMPLOYEE_UID,
    status: 'active', isPrimary: false,
  });
  for (const [index, locationId] of ['location-acceptance-a', 'location-acceptance-b'].entries()) {
    batch.set(db.collection('locations').doc(locationId), {
      name: `site-${index + 1}`, latitude: 30.01 + index, longitude: 31.2 + index,
      geofenceRadiusMeters: 120, isActive: true,
    });
    batch.set(db.collection('attendanceLocationAssignments').doc(`${EMPLOYEE_UID}_${locationId}`), {
      employeeUid: EMPLOYEE_UID, locationId, locationName: `site-${index + 1}`,
      status: 'active', isActive: true, priority: index, version: 1,
      effectiveFrom: admin.firestore.Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    });
  }
  batch.set(db.collection('publicConfig').doc('appSecurity'), {
    attendance_multi_location_v1: {
      enabled: true,
      actorIds: [EMPLOYEE_UID],
    },
  });
  await batch.commit();
  return actors;
}

async function tokensFor(actors) {
  const result = {};
  for (const [alias] of Object.entries(actors)) {
    const email = `${alias.replaceAll('_', '-')}@acceptance.invalid`;
    const response = await fetch(
      `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-key`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email, password: PASSWORD, returnSecureToken: true }),
      },
    );
    const body = await response.json();
    if (!response.ok || !body.idToken) fail(`Unable to issue emulator token for ${alias}.`);
    result[alias] = { token: body.idToken };
  }
  return result;
}

function startApi(actors) {
  const enabledActors = REQUIRED_ACTORS
    .filter((alias) => alias !== 'inactive' && alias !== 'out_of_scope')
    .map((alias) => actors[alias].uid);
  const flags = {
    company_os_organization_v1: { enabled: true, actorIds: enabledActors },
    company_os_multi_tree_v1: { enabled: true, actorIds: enabledActors },
  };
  const child = spawn(process.execPath, ['notification-web.js'], {
    cwd: __dirname,
    env: {
      ...process.env,
      PORT: String(PORT),
      NOTIFICATION_LISTENER_ENABLED: 'false',
      NOTIFICATION_BACKGROUND_SCHEDULER_ENABLED: 'false',
      COMPANY_OS_FEATURE_FLAGS_JSON: JSON.stringify(flags),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', (data) => process.stderr.write(`[acceptance-api] ${data}`));
  child.stderr.on('data', (data) => process.stderr.write(`[acceptance-api] ${data}`));
  return child;
}

async function waitForApi(child) {
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) fail(`Acceptance API exited with ${child.exitCode}.`);
    try {
      const response = await fetch(`http://127.0.0.1:${PORT}/health`);
      if (response.ok) return;
    } catch (_) {
      // The child is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  fail('Acceptance API did not become healthy within 20 seconds.');
}

async function main() {
  requireEmulators();
  const app = admin.initializeApp({ projectId: PROJECT_ID }, '008-009-emulator-seed');
  let child;
  try {
    const actorRecords = await seedFixture(app);
    const actors = await tokensFor(actorRecords);
    child = startApi(actorRecords);
    await waitForApi(child);
    const result = await runAuthorizationMatrix({
      baseUrl: `http://127.0.0.1:${PORT}`,
      actors,
      treeId: TREE_ID,
      targetEmployeeUid: EMPLOYEE_UID,
    });
    const evidence = {
      ok: true,
      environment: 'firebase-emulator',
      projectId: PROJECT_ID,
      completedAt: new Date().toISOString(),
      fixture: { actorCount: REQUIRED_ACTORS.length, treeCount: 1, locationCount: 2 },
      result,
    };
    const outputPath = path.join(__dirname, 'acceptance', '008-009-emulator-matrix-evidence.json');
    fs.writeFileSync(outputPath, `${JSON.stringify(evidence, null, 2)}\n`, { mode: 0o600 });
    process.stdout.write(`${JSON.stringify(evidence, null, 2)}\n`);
  } finally {
    if (child && child.exitCode === null) child.kill('SIGTERM');
    await app.delete();
  }
}

main().catch((error) => {
  process.stderr.write(`${JSON.stringify({ ok: false, message: String(error.message || error) })}\n`);
  process.exitCode = 1;
});
