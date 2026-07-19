const admin = require('firebase-admin');
const { installFirestoreCompatibility } = require('./firebase-service-account');
const {
  OPENING_DAY,
  currentCycle,
  cycleForKey,
  datePartsInCairo,
} = require('./payroll-cycle');

installFirestoreCompatibility(admin);

let serviceAccount;
try {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} catch (_) {
  console.error('FIREBASE_SERVICE_ACCOUNT is missing or invalid.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.cert(serviceAccount) });
const db = admin.firestore();

function previousDay(date) {
  return new Date(date.getTime() - (24 * 60 * 60 * 1000));
}

function sum(items, selector) {
  return items.reduce((total, item) => total + Number(selector(item) || 0), 0);
}

function groupByUser(snapshot) {
  const grouped = new Map();
  for (const doc of snapshot.docs) {
    const data = { id: doc.id, ...doc.data() };
    const userId = data.userId;
    if (!userId) continue;
    if (!grouped.has(userId)) grouped.set(userId, []);
    grouped.get(userId).push(data);
  }
  return grouped;
}

async function commitInChunks(operations, size = 400) {
  for (let index = 0; index < operations.length; index += size) {
    const batch = db.batch();
    for (const operation of operations.slice(index, index + size)) {
      operation(batch);
    }
    await batch.commit();
  }
}

async function runMonthlyTasks() {
  const now = new Date();
  const cairo = datePartsInCairo(now);
  const forcedCycleKey = String(process.env.PROCESS_CYCLE_KEY || '').trim();
  const force = process.env.FORCE_MONTHLY_CLOSE === 'true' || forcedCycleKey.length > 0;

  if (!force && Number(cairo.day) !== OPENING_DAY) {
    console.log(`Cairo date is day ${cairo.day}; cycle close runs only on day ${OPENING_DAY}.`);
    return;
  }

  const closingCycle = forcedCycleKey
    ? cycleForKey(forcedCycleKey)
    : currentCycle(previousDay(now));
  const openingCycle = currentCycle(
    new Date(`${closingCycle.nextStartDate}T12:00:00.000Z`),
  );
  console.log(
    `Closing cycle ${closingCycle.key} (${closingCycle.startDate} to ${closingCycle.endDate}); ` +
    `opening ${openingCycle.key}.`,
  );

  const closureRef = db.collection('payrollCycles').doc(closingCycle.key);
  const existingClosure = await closureRef.get();
  if (existingClosure.exists && existingClosure.data().status === 'finalized') {
    console.log(`Cycle ${closingCycle.key} is already finalized. Nothing to do.`);
    return;
  }

  const [usersSnap, attendanceSnap, permissionsSnap, leavesSnap, rewardsSnap, advancesSnap] =
    await Promise.all([
      db.collection('users').where('isActive', '==', true).get(),
      db.collection('attendance')
        .where('date', '>=', closingCycle.startDate)
        .where('date', '<=', closingCycle.endDate)
        .get(),
      db.collection('permissions').where('monthKey', '==', closingCycle.key).get(),
      db.collection('leaves').get(),
      db.collection('warningsRewards').where('monthKey', '==', closingCycle.key).get(),
      db.collection('advances').where('monthKey', '==', closingCycle.key).get(),
    ]);

  const attendanceByUser = groupByUser(attendanceSnap);
  const rewardsByUser = groupByUser(rewardsSnap);
  const advancesByUser = groupByUser(advancesSnap);
  const operations = [];
  let payrollEmployees = 0;
  let totalBaseSalary = 0;
  let totalDeductions = 0;
  let totalBonuses = 0;
  let totalAdvances = 0;
  let totalNetSalary = 0;
  let permissionsReset = 0;

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data();
    const userId = userDoc.id;

    if (user.permissionBalance?.lastResetMonth !== openingCycle.key) {
      operations.push((batch) => batch.update(userDoc.ref, {
        'permissionBalance.usedThisMonth': 0,
        'permissionBalance.usedHoursThisMonth': 0,
        'permissionBalance.lastResetMonth': openingCycle.key,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }));
      permissionsReset += 1;
    }

    if (user.role === 'super_admin') continue;
    payrollEmployees += 1;
    const attendance = attendanceByUser.get(userId) || [];
    const rewards = rewardsByUser.get(userId) || [];
    const advances = advancesByUser.get(userId) || [];
    const approvedDeductions = attendance.filter((item) =>
      item.salaryDeductionApprovalStatus === 'approved' &&
      Number(item.salaryDeductionAmount || 0) > 0,
    );
    const issuedBonuses = rewards.filter((item) =>
      ['reward', 'bonus_recommendation'].includes(item.type) &&
      ['issued', 'acknowledged'].includes(item.status) &&
      Number(item.amount || 0) > 0,
    );
    const approvedAdvances = advances.filter((item) => item.status === 'approved');
    const baseSalary = Number(user.baseMonthlySalary || 0);
    const deductions = sum(approvedDeductions, (item) => item.salaryDeductionAmount);
    const bonuses = sum(issuedBonuses, (item) => item.amount);
    const advanceTotal = sum(approvedAdvances, (item) => item.amount);
    const netSalary = Math.max(0, baseSalary - deductions + bonuses - advanceTotal);

    totalBaseSalary += baseSalary;
    totalDeductions += deductions;
    totalBonuses += bonuses;
    totalAdvances += advanceTotal;
    totalNetSalary += netSalary;

    const payrollRef = db.collection('payrollRuns').doc(`${userId}_${closingCycle.key}`);
    operations.push((batch) => batch.set(payrollRef, {
      userId,
      employeeId: user.employeeId || '',
      employeeName: user.displayName || '',
      department: user.department || '',
      managerId: user.managerId || '',
      monthKey: closingCycle.key,
      currency: user.salaryCurrency || 'EGP',
      baseSalary,
      attendanceDeductions: deductions,
      rewardsBonus: bonuses,
      advances: advanceTotal,
      netSalary,
      approvedDeductionCount: approvedDeductions.length,
      bonusRecordCount: issuedBonuses.length,
      advanceRecordCount: approvedAdvances.length,
      status: 'draft',
      calculatedBy: 'monthly-cycle-job',
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }));
  }

  const pendingDeductions = attendanceSnap.docs.filter((doc) =>
    doc.data().salaryDeductionApprovalStatus === 'pending_hr',
  ).length;
  const pendingPermissions = permissionsSnap.docs.filter((doc) =>
    String(doc.data().status || '').startsWith('pending_'),
  ).length;
  const overlappingLeaves = leavesSnap.docs.filter((doc) => {
    const data = doc.data();
    if (data.status !== 'approved') return false;
    const start = data.startDate?.toDate?.();
    const end = data.endDate?.toDate?.();
    if (!start || !end) return false;
    const key = (date) => new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(date);
    return key(start) <= closingCycle.endDate && key(end) >= closingCycle.startDate;
  }).length;

  operations.push((batch) => batch.set(closureRef, {
    cycleKey: closingCycle.key,
    startDate: closingCycle.startDate,
    endDate: closingCycle.endDate,
    nextCycleKey: openingCycle.key,
    status: 'finalized',
    finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
    finalizedBy: 'monthly-cycle-job',
    activeUsers: usersSnap.size,
    payrollEmployees,
    attendanceRecords: attendanceSnap.size,
    permissionRecords: permissionsSnap.size,
    approvedLeaveRecords: overlappingLeaves,
    pendingDeductions,
    pendingPermissions,
    totals: {
      baseSalary: totalBaseSalary,
      deductions: totalDeductions,
      bonuses: totalBonuses,
      advances: totalAdvances,
      netSalary: totalNetSalary,
    },
  }));

  await commitInChunks(operations);
  console.log(JSON.stringify({
    finalized: closingCycle.key,
    opened: openingCycle.key,
    payrollEmployees,
    attendanceRecords: attendanceSnap.size,
    permissionsReset,
    pendingDeductions,
    pendingPermissions,
    totalNetSalary,
  }));
}

runMonthlyTasks()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error running monthly tasks:', error);
    process.exit(1);
  });
