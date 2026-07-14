const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { installFirestoreCompatibility } = require('./firebase-service-account');
installFirestoreCompatibility(admin);

const dryRun = process.env.DRY_RUN !== 'false';
const mappingPath = process.env.EMAIL_UPDATES_CSV || './email_updates.csv';
const expectedProjectId =
  process.env.EXPECTED_FIREBASE_PROJECT_ID || 'zawolf-hr-system-60317';
const normalizeEmails = process.env.NORMALIZE_EMAILS !== 'false';
const failOnUnmatched = process.env.FAIL_ON_UNMATCHED === 'true';

let serviceAccount;
try {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '');
} catch (_) {
  console.error('FIREBASE_SERVICE_ACCOUNT is missing or invalid JSON.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

if (serviceAccount.project_id !== expectedProjectId) {
  console.error(
    [
      'Wrong Firebase project in FIREBASE_SERVICE_ACCOUNT.',
      `Expected: ${expectedProjectId}`,
      `Actual: ${serviceAccount.project_id}`,
    ].join('\n'),
  );
  process.exit(1);
}

const db = admin.firestore();
const auth = admin.auth();

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

function loadMappings() {
  const absolutePath = path.resolve(__dirname, mappingPath);
  const rows = parseCsv(fs.readFileSync(absolutePath, 'utf8'));
  const headers = rows.shift().map((header) => header.trim());
  return rows
    .filter((row) => row.some((cell) => String(cell || '').trim()))
    .map((row, index) => {
      const data = Object.fromEntries(
        headers.map((header, cellIndex) => [header, row[cellIndex] || '']),
      );
      const email = String(data.newEmail || '').trim();
      return {
        rowNumber: index + 2,
        loginName: String(data.loginName || '').trim(),
        currentEmail: String(data.currentEmail || '').trim().toLowerCase(),
        newEmail: normalizeEmails ? email.toLowerCase() : email,
        employeeId: String(data.employeeId || '').trim(),
        notes: String(data.notes || '').trim(),
      };
    });
}

async function findUserDocByEmployeeId(employeeId, currentEmail) {
  const snap = await db
    .collection('users')
    .where('employeeId', '==', employeeId)
    .get();
  if (snap.empty) return null;
  if (snap.size === 1) return snap.docs[0];

  const normalizedCurrentEmail = String(currentEmail || '').trim().toLowerCase();
  if (normalizedCurrentEmail) {
    const emailMatches = snap.docs.filter((doc) => {
      const data = doc.data() || {};
      return String(data.email || '').trim().toLowerCase() === normalizedCurrentEmail;
    });
    if (emailMatches.length === 1) return emailMatches[0];
  }

  const duplicateSummary = snap.docs
    .map((doc) => {
      const data = doc.data() || {};
      return `${doc.id}:${data.email || '(no email)'}`;
    })
    .join(', ');
  throw new Error(
    `More than one Firestore user has employeeId=${employeeId}. ` +
      `Set currentEmail in scripts/email_updates.csv to disambiguate. Matches: ${duplicateSummary}`,
  );
}

async function findAuthUserByCurrentEmail(currentEmail) {
  if (!currentEmail) return null;
  try {
    return await auth.getUserByEmail(currentEmail);
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

async function emailOwnerUid(email) {
  try {
    const user = await auth.getUserByEmail(email);
    return user.uid;
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

async function updateOne(mapping) {
  if (!mapping.employeeId) {
    const message = `UNMATCHED row ${mapping.rowNumber}: ${mapping.loginName} -> ${mapping.newEmail}`;
    if (failOnUnmatched) throw new Error(message);
    console.warn(message);
    return { status: 'unmatched' };
  }

  if (!mapping.newEmail || !mapping.newEmail.includes('@')) {
    throw new Error(`Invalid newEmail at row ${mapping.rowNumber}`);
  }

  const userDoc = await findUserDocByEmployeeId(
    mapping.employeeId,
    mapping.currentEmail,
  );
  if (!userDoc) {
    throw new Error(
      `No Firestore user found for employeeId=${mapping.employeeId} at row ${mapping.rowNumber}`,
    );
  }

  const data = userDoc.data() || {};
  const uid = userDoc.id;
  const currentFirestoreEmail = String(data.email || '').trim();
  const authUserByCurrentEmail = await findAuthUserByCurrentEmail(
    mapping.currentEmail,
  );
  if (authUserByCurrentEmail && authUserByCurrentEmail.uid !== uid) {
    throw new Error(
      `Current email ${mapping.currentEmail} belongs to Auth user ${authUserByCurrentEmail.uid}, ` +
        `but Firestore employeeId=${mapping.employeeId} resolved to ${uid}.`,
    );
  }
  const currentAuthUser = await auth.getUser(uid);
  const currentAuthEmail = String(currentAuthUser.email || '').trim();
  const ownerUid = await emailOwnerUid(mapping.newEmail);

  if (ownerUid && ownerUid !== uid) {
    throw new Error(
      `Target email ${mapping.newEmail} is already used by another Auth user (${ownerUid}).`,
    );
  }

  const alreadyUpdated =
    currentAuthEmail.toLowerCase() === mapping.newEmail.toLowerCase() &&
    currentFirestoreEmail.toLowerCase() === mapping.newEmail.toLowerCase();

  console.log(
    [
      `${alreadyUpdated ? 'OK' : dryRun ? 'WOULD_UPDATE' : 'UPDATE'}`,
      mapping.employeeId,
      data.displayName || '',
      `Auth: ${currentAuthEmail || '(empty)'} -> ${mapping.newEmail}`,
      `Firestore: ${currentFirestoreEmail || '(empty)'} -> ${mapping.newEmail}`,
    ].join(' | '),
  );

  if (dryRun || alreadyUpdated) {
    return { status: alreadyUpdated ? 'unchanged' : 'would_update' };
  }

  await auth.updateUser(uid, { email: mapping.newEmail });
  await userDoc.ref.update({
    email: mapping.newEmail,
    previousEmail: currentFirestoreEmail || currentAuthEmail || null,
    emailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { status: 'updated' };
}

async function main() {
  const mappings = loadMappings();
  const seenEmployeeIds = new Set();
  const seenEmails = new Set();
  for (const mapping of mappings) {
    if (mapping.employeeId) {
      const key = mapping.employeeId.toLowerCase();
      if (seenEmployeeIds.has(key)) {
        throw new Error(`Duplicate employeeId in mapping: ${mapping.employeeId}`);
      }
      seenEmployeeIds.add(key);
    }
    const emailKey = mapping.newEmail.toLowerCase();
    if (seenEmails.has(emailKey)) {
      throw new Error(`Duplicate target email in mapping: ${mapping.newEmail}`);
    }
    seenEmails.add(emailKey);
  }

  console.log(`Using Firebase service account: ${serviceAccount.client_email}`);
  console.log(`Firebase project id: ${serviceAccount.project_id}`);
  console.log(`Dry run: ${dryRun}`);
  console.log(`Normalize emails: ${normalizeEmails}`);
  console.log(`Loaded ${mappings.length} email mappings.`);

  const totals = {
    updated: 0,
    would_update: 0,
    unchanged: 0,
    unmatched: 0,
  };

  for (const mapping of mappings) {
    const result = await updateOne(mapping);
    totals[result.status] = (totals[result.status] || 0) + 1;
  }

  console.log('Summary:', totals);
  if (totals.unmatched > 0) {
    console.log(
      'Some rows are UNMATCHED. Fill employeeId in scripts/email_updates.csv before applying those rows.',
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
