const admin = require('firebase-admin');
const { initializeFirebase } = require('./dispatch-notifications');
const { deductionFor } = require('./auto-attendance');

const TIME_PERMISSION_TYPES = new Set([
  'early_leave',
  'late_arrival',
  'mid_shift_exit',
]);

function cairoDateKey(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

function nextApprovalStage(data) {
  const managerIds = Array.isArray(data.managerIds)
    ? data.managerIds.filter(Boolean)
    : [];
  const savedIndex = Number.isInteger(data.managerApprovalIndex)
    ? data.managerApprovalIndex
    : managerIds.indexOf(data.managerId);
  const currentIndex = savedIndex >= 0 ? savedIndex : 0;
  const nextIndex = currentIndex + 1;
  if (nextIndex < managerIds.length) {
    return {
      status: 'pending_manager',
      managerId: managerIds[nextIndex],
      managerApprovalIndex: nextIndex,
    };
  }
  return {
    status: data.requiresHrApproval === true ? 'pending_hr' : 'approved',
    managerId: data.managerId || '',
    managerApprovalIndex: Math.max(0, managerIds.length - 1),
  };
}

function dateWithinApprovedLeave(leave, dateKey) {
  if (leave.status !== 'approved') return false;
  const start = leave.startDate?.toDate?.();
  const end = leave.endDate?.toDate?.();
  if (!start || !end) return false;
  const startKey = cairoDateKey(start);
  const endKey = cairoDateKey(end);
  return dateKey >= startKey && dateKey <= endKey;
}

function isEligiblePermissionCandidate(data, dateKey) {
  return (
    data.requestDate === dateKey &&
    TIME_PERMISSION_TYPES.has(data.permissionType) &&
    typeof data.managerId === 'string' &&
    data.managerId.length > 0
  );
}

async function queueNotification(db, userId, notification) {
  if (!userId) return;
  const ref = db.collection('notifications').doc(userId).collection('items').doc();
  const batch = db.batch();
  batch.set(ref, {
    notificationId: ref.id,
    ...notification,
    isRead: false,
    pushSent: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.update(db.collection('users').doc(userId), {
    unreadNotifications: admin.firestore.FieldValue.increment(1),
  });
  await batch.commit();
}

async function notifyHr(db, permissionId, employeeName) {
  const hrSnap = await db
    .collection('users')
    .where('role', '==', 'hr_admin')
    .get();
  await Promise.all(
    hrSnap.docs
      .filter((doc) => doc.data().isActive !== false)
      .map((doc) =>
        queueNotification(db, doc.id, {
          type: 'permission_pending_hr',
          title: 'طلب إذن بانتظار مراجعة HR',
          body: `اكتملت مراحل المديرين لطلب ${employeeName} وينتظر قرار HR.`,
          data: { route: '/manager/requests', permissionId },
        }),
      ),
  );
}

function cairoMinutes(date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Cairo',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );
  return Number(values.hour) * 60 + Number(values.minute);
}

function parseMinutes(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const [hour, minute] = value.split(':').map(Number);
  return Number.isFinite(hour) && Number.isFinite(minute)
    ? hour * 60 + minute
    : fallback;
}

async function reconcileApprovedPermission(db, permission) {
  const attendanceRef = db
    .collection('attendance')
    .doc(`${permission.userId}_${permission.requestDate}`);
  const [attendanceDoc, userDoc, companyDoc] = await Promise.all([
    attendanceRef.get(),
    db.collection('users').doc(permission.userId).get(),
    db.collection('companies').doc('zawolf').get(),
  ]);
  if (!attendanceDoc.exists || !userDoc.exists) return;

  const attendance = attendanceDoc.data();
  const user = userDoc.data();
  const policy = companyDoc.data()?.attendancePolicy || companyDoc.data() || {};
  const noDeduction = {
    isLate: false,
    lateMinutes: 0,
    salaryDeductionFraction: 0,
    salaryDeductionAmount: 0,
    salaryDeductionCode: 'none',
    salaryDeductionLabel: 'لا يوجد خصم',
    salaryDeductionApprovalStatus: 'none',
    reconciledPermissionId: permission.permissionId,
    deductionReconciledAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (
    permission.permissionType === 'late_arrival' &&
    attendance.checkInTime?.toDate
  ) {
    const checkIn = attendance.checkInTime.toDate();
    const baseStart = parseMinutes(
      user.workSchedule?.startTime,
      parseMinutes(policy.defaultStartTime, 9 * 60),
    );
    const deduction = deductionFor(
      cairoMinutes(checkIn),
      baseStart + Number(permission.durationMinutes || 0),
      policy,
      user.baseMonthlySalary,
      user.salaryCurrency,
    );
    await attendanceRef.update({
      status: deduction.status,
      isLate: deduction.fraction > 0,
      lateMinutes: deduction.lateMinutes,
      salaryDeductionFraction: deduction.fraction,
      salaryDeductionAmount: deduction.amount,
      salaryCurrency: deduction.currency,
      salaryDeductionCode: deduction.code,
      salaryDeductionLabel: deduction.label,
      salaryDeductionApprovalStatus:
        deduction.fraction > 0 ? 'pending_hr' : 'none',
      reconciledPermissionId: permission.permissionId,
      deductionReconciledAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else if (
    permission.permissionType === 'early_leave' &&
    attendance.checkOutTime?.toDate
  ) {
    const baseEnd = parseMinutes(
      user.workSchedule?.endTime,
      parseMinutes(policy.defaultEndTime, 17 * 60),
    );
    const allowedEnd = baseEnd - Number(permission.durationMinutes || 0);
    if (cairoMinutes(attendance.checkOutTime.toDate()) >= allowedEnd) {
      await attendanceRef.update(noDeduction);
    }
  }
}

async function processManagerLeavePermissionBypasses() {
  initializeFirebase();
  const db = admin.firestore();
  const dateKey = cairoDateKey();
  const pendingSnap = await db
    .collection('permissions')
    .where('status', '==', 'pending_manager')
    .get();
  const candidates = pendingSnap.docs.filter((doc) =>
    isEligiblePermissionCandidate(doc.data(), dateKey),
  );

  const managerIds = [...new Set(candidates.map((doc) => doc.data().managerId))];
  const leaveByManager = new Map();
  await Promise.all(
    managerIds.map(async (managerId) => {
      const leaves = await db
        .collection('leaves')
        .where('userId', '==', managerId)
        .get();
      leaveByManager.set(
        managerId,
        leaves.docs.some((doc) => dateWithinApprovedLeave(doc.data(), dateKey)),
      );
    }),
  );

  let processed = 0;
  let failed = 0;
  for (const candidate of candidates) {
    const initial = candidate.data();
    if (leaveByManager.get(initial.managerId) !== true) continue;

    try {
      const result = await db.runTransaction(async (transaction) => {
        const fresh = await transaction.get(candidate.ref);
        if (!fresh.exists) return null;
        const data = fresh.data();
        if (
          data.status !== 'pending_manager' ||
          data.requestDate !== dateKey ||
          data.managerId !== initial.managerId ||
          !TIME_PERMISSION_TYPES.has(data.permissionType)
        ) {
          return null;
        }

        const next = nextApprovalStage(data);
        const managerIdsForRequest = Array.isArray(data.managerIds)
          ? data.managerIds.filter(Boolean)
          : [];
        const managerNames = Array.isArray(data.managerNames)
          ? data.managerNames
          : [];
        const currentIndex = Number.isInteger(data.managerApprovalIndex)
          ? data.managerApprovalIndex
          : managerIdsForRequest.indexOf(data.managerId);
        const managerName =
          managerNames[currentIndex] ||
          data.managerName ||
          'المدير المسؤول';
        const now = admin.firestore.Timestamp.now();
        const actorName = `${managerName} (إجازة معتمدة - اعتماد تلقائي)`;
        const patch = {
          ...next,
          managerName:
            next.status === 'pending_manager'
              ? managerNames[next.managerApprovalIndex] || null
              : data.managerName || null,
          managerApprovalTrail: admin.firestore.FieldValue.arrayUnion({
            reviewerId: data.managerId,
            reviewerName: actorName,
            reviewerRole: 'system_manager_leave',
            reviewedAt: now,
            timestamp: now,
            status: 'approved',
            stage: Math.max(0, currentIndex),
            automaticReason: 'manager_approved_leave',
          }),
          approvalHistory: admin.firestore.FieldValue.arrayUnion({
            stage: 'manager',
            status: 'approved',
            actorId: data.managerId,
            actorName,
            timestamp: now,
            automaticReason: 'manager_approved_leave',
          }),
          reviewedBy: data.managerId,
          reviewerName: actorName,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          managerReviewedBy: data.managerId,
          managerReviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          automaticManagerLeaveBypass: true,
          automaticManagerLeaveBypassAt:
            admin.firestore.FieldValue.serverTimestamp(),
        };

        if (next.status === 'approved') {
          patch.finalApproverId = data.managerId;
          patch.finalApproverName = actorName;
          patch.finalApprovalAt = admin.firestore.FieldValue.serverTimestamp();
          if (data.isDeductible !== true) {
            transaction.update(db.collection('users').doc(data.userId), {
              'permissionBalance.usedThisMonth':
                admin.firestore.FieldValue.increment(1),
              'permissionBalance.usedHoursThisMonth':
                admin.firestore.FieldValue.increment(
                  Number(data.durationMinutes || 0) / 60,
                ),
            });
          }
        }
        transaction.update(candidate.ref, patch);
        return { data, next, actorName };
      });
      if (!result) continue;
      processed++;

      if (result.next.status === 'pending_manager') {
        await queueNotification(db, result.next.managerId, {
          type: 'permission_pending_manager',
          title: 'طلب إذن بانتظار موافقتك',
          body: `${result.data.employeeName} تجاوز مرحلة مدير في إجازة وينتظر قرارك.`,
          data: {
            route: '/manager/requests',
            permissionId: candidate.id,
          },
        });
      } else if (result.next.status === 'pending_hr') {
        await notifyHr(db, candidate.id, result.data.employeeName);
      } else {
        await reconcileApprovedPermission(db, {
          ...result.data,
          permissionId: candidate.id,
        });
        await queueNotification(db, result.data.userId, {
          type: 'permission_approved',
          title: 'تم قبول طلب الإذن',
          body: `اكتملت موافقات طلب إذنك ليوم ${dateKey}.`,
          data: {
            route: '/employee/requests',
            permissionId: candidate.id,
          },
        });
      }
    } catch (error) {
      failed++;
      console.error(
        `Manager-leave permission bypass failed for ${candidate.id}:`,
        error,
      );
    }
  }

  return { found: candidates.length, processed, failed, date: dateKey };
}

if (require.main === module) {
  processManagerLeavePermissionBypasses()
    .then((result) => {
      console.log('Manager-leave permission bypass complete:', result);
      process.exit(0);
    })
    .catch((error) => {
      console.error('Manager-leave permission bypass failed:', error);
      process.exit(1);
    });
}

module.exports = {
  TIME_PERMISSION_TYPES,
  cairoDateKey,
  dateWithinApprovedLeave,
  isEligiblePermissionCandidate,
  nextApprovalStage,
  processManagerLeavePermissionBypasses,
};
