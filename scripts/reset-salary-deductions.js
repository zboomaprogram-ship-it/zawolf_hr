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
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const dryRun = process.env.DRY_RUN !== 'false';
const confirmation = process.env.RESET_CONFIRMATION || '';
const requiredConfirmation = 'RESET_ALL_SALARY_DEDUCTIONS';
const noDeductionLabel = 'لا يوجد خصم';

function hasDeduction(data) {
  return Number(data.salaryDeductionFraction || 0) !== 0 ||
    Number(data.salaryDeductionAmount || 0) !== 0 ||
    String(data.salaryDeductionCode || 'none') !== 'none' ||
    String(data.salaryDeductionApprovalStatus || 'none') !== 'none';
}

function deductionResetPatch() {
  return {
    salaryDeductionFraction: 0,
    salaryDeductionAmount: 0,
    salaryDeductionCode: 'none',
    salaryDeductionLabel: noDeductionLabel,
    salaryDeductionApprovalStatus: 'none',
    salaryDeductionDetectedAt: admin.firestore.FieldValue.delete(),
    salaryDeductionReviewedBy: admin.firestore.FieldValue.delete(),
    salaryDeductionReviewedAt: admin.firestore.FieldValue.delete(),
  };
}

function payrollHasDeduction(data) {
  return Number(data.attendanceDeductions || 0) !== 0 ||
    Number(data.approvedDeductionCount || 0) !== 0;
}

function payrollResetPatch(data) {
  const baseSalary = Number(data.baseSalary || 0);
  const rewardsBonus = Number(data.rewardsBonus || 0);
  const advances = Number(data.advances || 0);
  return {
    attendanceDeductions: 0,
    approvedDeductionCount: 0,
    netSalary: Math.max(0, baseSalary + rewardsBonus - advances),
    status: 'draft',
    reviewedBy: admin.firestore.FieldValue.delete(),
    reviewedAt: admin.firestore.FieldValue.delete(),
    calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    calculatedBy: 'salary-deduction-reset',
  };
}

async function main() {
  if (!dryRun && confirmation !== requiredConfirmation) {
    throw new Error(
      `Live reset requires RESET_CONFIRMATION=${requiredConfirmation}`,
    );
  }

  console.log(`Using Firebase project: ${serviceAccount.project_id}`);
  console.log(`Dry run: ${dryRun}`);
  console.log('Scanning deduction-bearing records...');

  const [attendanceSnapshot, permissionsSnapshot, payrollSnapshot] =
    await Promise.all([
      db.collection('attendance').get(),
      db.collection('permissions').get(),
      db.collection('payrollRuns').get(),
    ]);

  const attendance = attendanceSnapshot.docs.filter((doc) =>
    hasDeduction(doc.data()),
  );
  const permissions = permissionsSnapshot.docs.filter((doc) =>
    hasDeduction(doc.data()),
  );
  const payrollRuns = payrollSnapshot.docs.filter((doc) =>
    payrollHasDeduction(doc.data()),
  );

  console.log(`Attendance deductions found: ${attendance.length}`);
  console.log(`Permission deductions found: ${permissions.length}`);
  console.log(`Payroll summaries requiring recalculation: ${payrollRuns.length}`);

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

  for (const doc of attendance) {
    batch.update(doc.ref, deductionResetPatch());
    pendingOperations++;
    await commit();
  }
  for (const doc of permissions) {
    batch.update(doc.ref, deductionResetPatch());
    pendingOperations++;
    await commit();
  }
  for (const doc of payrollRuns) {
    batch.update(doc.ref, payrollResetPatch(doc.data()));
    pendingOperations++;
    await commit();
  }
  await commit(true);

  console.log('Salary deduction reset complete.');
  console.log(`Attendance records reset: ${attendance.length}`);
  console.log(`Permission records reset: ${permissions.length}`);
  console.log(`Payroll summaries reset: ${payrollRuns.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
