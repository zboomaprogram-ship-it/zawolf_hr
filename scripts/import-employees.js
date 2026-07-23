const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { installFirestoreCompatibility } = require('./firebase-service-account');
installFirestoreCompatibility(admin);

const initialPassword = process.env.INITIAL_EMPLOYEE_PASSWORD || 'ZW@0000';
const csvPath = process.env.IMPORT_CSV_PATH || '../zawolf_employee_accounts_import.csv';
const dryRun = process.env.DRY_RUN !== 'false';
const expectedProjectId =
  process.env.EXPECTED_FIREBASE_PROJECT_ID || 'zawolf-hr-system-60317';

let db;
let auth;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  let serviceAccount;
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (_) {
    console.error('FIREBASE_SERVICE_ACCOUNT is invalid JSON.');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.cert(serviceAccount),
  });
  console.log(`Using Firebase service account: ${serviceAccount.client_email}`);
  console.log(`Firebase project id: ${serviceAccount.project_id}`);
  if (serviceAccount.project_id !== expectedProjectId) {
    console.error(
      [
        `Wrong Firebase project in FIREBASE_SERVICE_ACCOUNT.`,
        `Expected: ${expectedProjectId}`,
        `Actual: ${serviceAccount.project_id}`,
        `Replace the GitHub secret with a service account JSON from the correct Firebase project.`,
      ].join('\n'),
    );
    process.exit(1);
  }
  db = admin.firestore();
  auth = admin.auth();
} else if (!dryRun) {
  console.error('FIREBASE_SERVICE_ACCOUNT is required when DRY_RUN=false.');
  process.exit(1);
}

function currentCairoMonthKey() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date());
  return `${parts.find((p) => p.type === 'year').value}-${parts.find((p) => p.type === 'month').value}`;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  const input = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < input.length; i++) {
    const char = input[i];
    const next = input[i + 1];
    if (quoted) {
      if (char === '"' && next === '"') {
        cell += '"';
        i++;
      } else if (char === '"') {
        quoted = false;
      } else {
        cell += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ',') {
      row.push(cell);
      cell = '';
    } else if (char === '\n') {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
    } else if (char !== '\r') {
      cell += char;
    }
  }
  if (cell.length || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

function normalizeRole(role) {
  const value = String(role || '').trim().toLowerCase().replace(/[\s-]+/g, '_');
  if (['hr', 'hradmin', 'hr_admin'].includes(value)) return 'hr_admin';
  if (['hrmanager', 'hr_manager'].includes(value)) return 'hr_manager';
  if (['super', 'superadmin', 'super_admin', 'ceo', 'owner'].includes(value)) {
    return 'super_admin';
  }
  if (['manager', 'manger'].includes(value)) return 'manager';
  return 'employee';
}

function canBeSupervisor(role) {
  return ['manager', 'hr_admin', 'hr_manager', 'super_admin'].includes(role);
}

function splitList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

async function getOrCreateAuthUser(row) {
  if (dryRun && !auth) {
    return { uid: `dry_${row.employeeId}`, email: row.email };
  }
  try {
    return await auth.getUserByEmail(row.email);
  } catch (error) {
    if (
      error.code === 'auth/internal-error' &&
      String(error.message || '').includes('identitytoolkit.googleapis.com')
    ) {
      throw new Error(
        [
          'Firebase Auth API is disabled for this Firebase project.',
          'Enable Identity Toolkit API, then rerun this workflow:',
          'https://console.developers.google.com/apis/api/identitytoolkit.googleapis.com/overview?project=658276952100',
          'Also make sure Firebase Authentication is enabled and Email/Password sign-in is turned on.',
        ].join('\n'),
      );
    }
    if (error.code === 'auth/insufficient-permission') {
      throw new Error(
        [
          'The FIREBASE_SERVICE_ACCOUNT secret is valid, but it cannot manage Firebase Authentication users.',
          'Fix it in Google Cloud IAM:',
          '1. Open Google Cloud Console -> IAM.',
          '2. Find the service account email from your FIREBASE_SERVICE_ACCOUNT JSON client_email.',
          '3. Grant it Firebase Authentication Admin.',
          '4. Also keep Firestore access, for example Cloud Datastore User or Firebase Admin, so user documents can be written.',
          '5. Wait a few minutes, then rerun this workflow with dry_run=false.',
        ].join('\n'),
      );
    }
    if (error.code !== 'auth/user-not-found') throw error;
    if (dryRun) {
      return { uid: `dry_${row.employeeId}`, email: row.email };
    }
    return auth.createUser({
      email: row.email,
      password: initialPassword,
      displayName: row.displayName,
      disabled: false,
    });
  }
}

function buildUserDoc(row, userRecord, supervisors) {
  const primary = supervisors[0];
  return {
    uid: userRecord.uid,
    email: row.email,
    displayName: row.displayName,
    role: row.role,
    employeeId: row.employeeId,
    department: row.department,
    position: row.position,
    locationId: row.locationId,
    locationName: row.locationName,
    baseMonthlySalary: Number(row.baseMonthlySalary || 0),
    salaryCurrency: row.salaryCurrency || 'EGP',
    managerId: primary?.uid || null,
    managerName: primary?.displayName || null,
    managerIds: supervisors.map((item) => item.uid),
    managerNames: supervisors.map((item) => item.displayName),
    managerCodes: supervisors.map((item) => item.employeeId),
    isActive: true,
    leaveBalance: { annual: 15, sick: 14, casual: 7, daysOff: 15 },
    permissionBalance: {
      usedThisMonth: 0,
      usedHoursThisMonth: 0,
      lastResetMonth: currentCairoMonthKey(),
    },
    workSchedule: {
      startTime: '09:00',
      endTime: '17:00',
      workDays: [6, 7, 1, 2, 3, 4],
    },
    notificationTokens: [],
    unreadNotifications: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function seedReferenceData(records) {
  if (dryRun || !db) return;

  const departments = [...new Set(records.map((row) => row.department).filter(Boolean))];
  const jobTitles = [...new Set(records.map((row) => row.position).filter(Boolean))];
  const locations = [
    ...new Map(
      records
        .filter((row) => row.locationId)
        .map((row) => [
          row.locationId,
          {
            locationId: row.locationId,
            name: row.locationName || row.locationId,
          },
        ]),
    ).values(),
  ];

  for (const name of departments) {
    const existing = await db
      .collection('departments')
      .where('name', '==', name)
      .limit(1)
      .get();
    if (existing.empty) {
      await db.collection('departments').add({
        name,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  for (const name of jobTitles) {
    const existing = await db
      .collection('job_titles')
      .where('name', '==', name)
      .limit(1)
      .get();
    if (existing.empty) {
      await db.collection('job_titles').add({
        name,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  for (const location of locations) {
    const ref = db.collection('locations').doc(location.locationId);
    const existing = await ref.get();
    if (!existing.exists) {
      await ref.set({
        companyId: 'zawolf',
        name: location.name,
        address: location.name,
        latitude: 0,
        longitude: 0,
        geofenceRadiusMeters: 50,
        isActive: true,
        employeeCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
}

async function main() {
  const absoluteCsvPath = path.resolve(__dirname, csvPath);
  const text = fs.readFileSync(absoluteCsvPath, 'utf8');
  const rows = parseCsv(text);
  const headers = rows.shift().map((header) => header.trim());
  const records = rows
    .filter((row) => row.some((cell) => String(cell).trim()))
    .map((row) => {
      const data = Object.fromEntries(headers.map((header, index) => [header, row[index] || '']));
      return {
        email: data.email.trim(),
        displayName: data.displayName.trim(),
        employeeId: data.employeeId.trim(),
        role: normalizeRole(data.role),
        department: data.department.trim(),
        position: data.position.trim(),
        locationId: data.locationId.trim(),
        locationName: data.locationName.trim() || data.locationId.trim(),
        baseMonthlySalary: data.baseMonthlySalary.trim(),
        salaryCurrency: data.salaryCurrency.trim() || 'EGP',
        managerCodes: splitList(data.managerCodes),
      };
    });

  const byCode = new Map();
  let createdAuth = 0;
  let existingAuth = 0;

  await seedReferenceData(records);

  for (const record of records) {
    if (!record.email || !record.displayName || !record.employeeId) {
      throw new Error(`Missing required data for row: ${JSON.stringify(record)}`);
    }
    const before = dryRun ? null : await auth.getUserByEmail(record.email).catch(() => null);
    const userRecord = await getOrCreateAuthUser(record);
    if (before) existingAuth++;
    else createdAuth++;
    byCode.set(record.employeeId.toLowerCase(), {
      uid: userRecord.uid,
      displayName: record.displayName,
      employeeId: record.employeeId,
      role: record.role,
    });
    record.uid = userRecord.uid;
  }

  let writtenDocs = 0;
  for (const record of records) {
    const supervisors = record.managerCodes.map((code) => {
      const supervisor = byCode.get(code.toLowerCase());
      if (!supervisor) {
        throw new Error(`Supervisor code not found for ${record.employeeId}: ${code}`);
      }
      if (!canBeSupervisor(supervisor.role)) {
        throw new Error(`Supervisor code ${code} belongs to a non-supervisor role.`);
      }
      return supervisor;
    });
    const doc = buildUserDoc(record, { uid: record.uid, email: record.email }, supervisors);
    if (!dryRun) {
      await db.collection('users').doc(record.uid).set(doc, { merge: true });
    }
    writtenDocs++;
  }

  console.log(
    JSON.stringify(
      {
        dryRun,
        accounts: records.length,
        createdAuth,
        existingAuth,
        writtenDocs,
        seededReferenceData: !dryRun,
        csv: absoluteCsvPath,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
