const admin = require('firebase-admin');
const { installFirestoreCompatibility } = require('./firebase-service-account');
installFirestoreCompatibility(admin);

let serviceAccount;
try {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '');
} catch (e) {
  console.error('FIREBASE_SERVICE_ACCOUNT is missing or invalid JSON.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

const db = admin.firestore();

const dryRun = process.env.DRY_RUN !== 'false';
const deleteBadDocs = process.env.DELETE_BAD_DOCS === 'true';
const dateFrom = process.env.DATE_FROM || process.env.DATE || cairoDateStr(new Date());
const dateTo = process.env.DATE_TO || dateFrom;

function cairoDateStr(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function isTimestamp(value) {
  return value && typeof value.toDate === 'function';
}

function formatValue(value) {
  if (isTimestamp(value)) return value.toDate().toISOString();
  if (value === undefined) return 'undefined';
  return JSON.stringify(value);
}

function hasBadNoCheckInShape(data) {
  const hasCheckIn = Boolean(data.checkInTime);
  if (hasCheckIn) return false;

  const hasCheckout = Boolean(data.checkOutTime);
  const status = String(data.status || '');
  const deductionStatus = String(data.salaryDeductionApprovalStatus || '');
  const deductionCode = String(data.salaryDeductionCode || '');
  const hasDeduction =
    deductionStatus === 'pending_hr' ||
    deductionStatus === 'approved' ||
    deductionCode === 'full_day' ||
    deductionCode === 'missed_checkout_quarter_day' ||
    deductionCode === 'early_checkout_quarter_day' ||
    deductionCode === 'late_checkout_after_11_quarter_day';

  return status === 'absent' || hasCheckout || hasDeduction;
}

function cleanupPatch(data) {
  const patch = {
    cleanupStatus: 'cancelled_bad_attendance_record',
    cleanupReason:
      'Removed old invalid attendance state: record had no checkInTime.',
    cleanupAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (data.salaryDeductionApprovalStatus && data.salaryDeductionApprovalStatus !== 'none') {
    patch.salaryDeductionApprovalStatus = 'rejected';
    patch.salaryDeductionReviewedBy = 'cleanup-script';
    patch.salaryDeductionReviewedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  return patch;
}

async function main() {
  if (dateFrom > dateTo) {
    throw new Error(`DATE_FROM (${dateFrom}) must be <= DATE_TO (${dateTo}).`);
  }

  console.log('Attendance cleanup starting...');
  console.log(`Date range: ${dateFrom} -> ${dateTo}`);
  console.log(`Dry run: ${dryRun}`);
  console.log(`Delete bad docs: ${deleteBadDocs}`);

  const snapshot = await db
    .collection('attendance')
    .where('date', '>=', dateFrom)
    .where('date', '<=', dateTo)
    .get();

  const badDocs = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!hasBadNoCheckInShape(data)) continue;
    badDocs.push({ doc, data });
  }

  console.log(`Scanned ${snapshot.size} attendance records.`);
  console.log(`Found ${badDocs.length} invalid no-check-in records.`);

  for (const item of badDocs) {
    const { doc, data } = item;
    console.log(
      [
        `- ${doc.id}`,
        `date=${data.date}`,
        `userId=${data.userId || ''}`,
        `employee=${data.employeeName || ''}`,
        `status=${data.status || ''}`,
        `checkInTime=${formatValue(data.checkInTime)}`,
        `checkOutTime=${formatValue(data.checkOutTime)}`,
        `deduction=${data.salaryDeductionCode || 'none'}`,
        `deductionStatus=${data.salaryDeductionApprovalStatus || 'none'}`,
      ].join(' | '),
    );
  }

  if (dryRun || badDocs.length === 0) {
    console.log('Dry run complete. No Firestore writes were made.');
    return;
  }

  let batch = db.batch();
  let ops = 0;
  let changed = 0;

  async function commitIfNeeded(force = false) {
    if (ops === 0) return;
    if (!force && ops < 450) return;
    await batch.commit();
    console.log(`Committed ${ops} cleanup operations.`);
    batch = db.batch();
    ops = 0;
  }

  for (const { doc, data } of badDocs) {
    if (deleteBadDocs) {
      batch.delete(doc.ref);
    } else {
      batch.update(doc.ref, cleanupPatch(data));
    }
    ops++;
    changed++;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
  console.log(`Cleanup complete. Changed ${changed} records.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
