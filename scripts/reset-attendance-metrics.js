const admin = require('firebase-admin');
const {
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
} = require('./firebase-service-account');

installFirestoreCompatibility(admin);

const serviceAccount = parseFirebaseServiceAccount(
  process.env.FIREBASE_SERVICE_ACCOUNT || '',
);

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

const db = admin.firestore();
const dryRun = process.env.DRY_RUN !== 'false';
const confirmation = process.env.RESET_CONFIRMATION || '';
const requiredConfirmation = 'RESET_CURRENT_MONTH_ATTENDANCE_METRICS';
const monthKey = process.env.MONTH_KEY || currentCairoMonthKey();

function currentCairoMonthKey() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date());
  const year = parts.find((part) => part.type === 'year').value;
  const month = parts.find((part) => part.type === 'month').value;
  return `${year}-${month}`;
}

function nextMonthDateKey(value) {
  const [year, month] = value.split('-').map(Number);
  if (!year || !month || month < 1 || month > 12) {
    throw new Error(`Invalid MONTH_KEY: ${value}. Expected YYYY-MM.`);
  }
  const nextYear = month === 12 ? year + 1 : year;
  const nextMonth = month === 12 ? 1 : month + 1;
  return `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;
}

function isAbsent(data) {
  return String(data.status || '') === 'absent';
}

function isLate(data) {
  return data.isLate === true ||
    String(data.status || '') === 'late' ||
    String(data.status || '').startsWith('late_');
}

function attendanceResetPatch() {
  return {
    status: 'present',
    isLate: false,
    lateMinutes: 0,
    salaryDeductionFraction: 0,
    salaryDeductionAmount: 0,
    salaryDeductionCode: 'none',
    salaryDeductionLabel: 'لا يوجد خصم',
    salaryDeductionApprovalStatus: 'none',
    salaryDeductionDetectedAt: admin.firestore.FieldValue.delete(),
    salaryDeductionReviewedBy: admin.firestore.FieldValue.delete(),
    salaryDeductionReviewedAt: admin.firestore.FieldValue.delete(),
  };
}

function productivityResetPatch(data) {
  const taskCompletion = Number(data.taskCompletionScore || 0);
  const taskQuality = Number(data.taskQualityScore || 0);
  const kpi = Number(data.kpiScore || 0);
  const overall =
    (100 * 0.25) +
    (100 * 0.15) +
    (taskCompletion * 0.25) +
    (taskQuality * 0.15) +
    (kpi * 0.20);
  return {
    attendanceScore: 100,
    punctualityScore: 100,
    absentDays: 0,
    lateDays: 0,
    overallScore: Math.max(0, Math.min(100, overall)),
    calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function performanceResetPatch(data) {
  const previousAttendance = Number(data.attendanceScore || 0);
  const previousPunctuality = Number(data.punctualityScore || 0);
  const previousOverall = Number(data.overallScore || 0);
  const remainingScore =
    (previousOverall * 6) - previousAttendance - previousPunctuality;
  const overall = Math.max(0, Math.min(100, (200 + remainingScore) / 6));
  return {
    attendanceScore: 100,
    punctualityScore: 100,
    overallScore: overall,
    grade: overall >= 90 ? 'A' : overall >= 80 ? 'B' : overall >= 70 ? 'C' : overall >= 60 ? 'D' : 'F',
  };
}

async function main() {
  if (!dryRun && confirmation !== requiredConfirmation) {
    throw new Error(
      `Live reset requires RESET_CONFIRMATION=${requiredConfirmation}`,
    );
  }

  const firstDate = `${monthKey}-01`;
  const nextDate = nextMonthDateKey(monthKey);
  console.log(`Using Firebase project: ${serviceAccount.project_id}`);
  console.log(`Month: ${monthKey}`);
  console.log(`Dry run: ${dryRun}`);

  const [attendanceSnapshot, productivitySnapshot, performanceSnapshot] =
    await Promise.all([
      db.collection('attendance')
        .where('date', '>=', firstDate)
        .where('date', '<', nextDate)
        .get(),
      db.collection('productivityScores')
        .where('monthKey', '==', monthKey)
        .get(),
      db.collection('performance')
        .where('monthKey', '==', monthKey)
        .get(),
    ]);

  const absenceDocs = attendanceSnapshot.docs.filter((doc) =>
    isAbsent(doc.data()),
  );
  const lateDocs = attendanceSnapshot.docs.filter((doc) =>
    !isAbsent(doc.data()) && isLate(doc.data()),
  );
  const syntheticAbsences = absenceDocs.filter((doc) =>
    !doc.data().checkInTime,
  );
  const attendedAbsences = absenceDocs.filter((doc) =>
    Boolean(doc.data().checkInTime),
  );

  console.log(`Synthetic absence records to remove: ${syntheticAbsences.length}`);
  console.log(`Attendance records to normalize: ${lateDocs.length + attendedAbsences.length}`);
  console.log(`Productivity scores to reset: ${productivitySnapshot.size}`);
  console.log(`Published performance records to refresh: ${performanceSnapshot.size}`);

  if (dryRun) {
    console.log('Dry run complete. No Firestore data was changed.');
    return;
  }

  let batch = db.batch();
  let pendingOperations = 0;
  let committedOperations = 0;

  async function commit(force = false) {
    if (pendingOperations === 0) return;
    if (!force && pendingOperations < 400) return;
    await batch.commit();
    committedOperations += pendingOperations;
    console.log(`Committed ${committedOperations} reset operations.`);
    batch = db.batch();
    pendingOperations = 0;
  }

  for (const doc of syntheticAbsences) {
    batch.delete(doc.ref);
    pendingOperations++;
    await commit();
  }
  for (const doc of [...lateDocs, ...attendedAbsences]) {
    batch.update(doc.ref, attendanceResetPatch());
    pendingOperations++;
    await commit();
  }
  for (const doc of productivitySnapshot.docs) {
    batch.update(doc.ref, productivityResetPatch(doc.data()));
    pendingOperations++;
    await commit();
  }
  for (const doc of performanceSnapshot.docs) {
    batch.update(doc.ref, performanceResetPatch(doc.data()));
    pendingOperations++;
    await commit();
  }
  await commit(true);

  console.log('Attendance metrics reset complete.');
  console.log(`Absence records removed: ${syntheticAbsences.length}`);
  console.log(`Attendance records normalized: ${lateDocs.length + attendedAbsences.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
