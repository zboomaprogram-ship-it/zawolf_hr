'use strict';

const ALLOWED_STATUSES = new Set(['pending_manager', 'pending_hr', 'approved', 'rejected']);
const VALID_DURATIONS = new Set([60, 120, 180, 240]);

function earlyLeaveFraction(durationMinutes) {
  const minutes = Number(durationMinutes);
  if (!VALID_DURATIONS.has(minutes)) {
    const error = new Error('Early-leave duration is invalid.');
    error.code = 'invalid_early_leave_request';
    throw error;
  }
  return Math.min(1, (minutes / 60) * 0.25);
}

function parseMinutes(value, fallback) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ''));
  if (!match) return fallback;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  return hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59
    ? hours * 60 + minutes
    : fallback;
}

const CAIRO_TIME = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Africa/Cairo', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
});

function cairoMinutes(date) {
  const parts = Object.fromEntries(CAIRO_TIME.formatToParts(date).map((p) => [p.type, p.value]));
  return Number(parts.hour) * 60 + Number(parts.minute);
}

function validateEarlyLeaveForCheckout({ permissionId, permission, actorUid, dateKey, eventTime, normalEndTime }) {
  if (!permissionId || !permission || permission.permissionType !== 'early_leave' ||
      permission.userId !== actorUid || permission.requestDate !== dateKey ||
      !ALLOWED_STATUSES.has(String(permission.status || ''))) {
    const error = new Error('Early-leave request is invalid.');
    error.code = permission?.userId && permission.userId !== actorUid
      ? 'early_leave_not_owned'
      : 'invalid_early_leave_request';
    throw error;
  }
  const requestedMinutes = Number(permission.durationMinutes || 0);
  const potentialDayFraction = earlyLeaveFraction(requestedMinutes);
  const normalEndMinutes = parseMinutes(normalEndTime, 17 * 60);
  const requestedCheckoutMinutes = normalEndMinutes - requestedMinutes;
  const actualMinutes = cairoMinutes(eventTime);
  if (actualMinutes < requestedCheckoutMinutes) {
    const error = new Error('Checkout is earlier than the requested departure time.');
    error.code = 'early_checkout_too_early';
    throw error;
  }
  return {
    permissionId,
    requestStatus: permission.status,
    requestedMinutes,
    requestedCheckoutMinutes,
    normalEndMinutes,
    actualMinutes,
    potentialDayFraction,
    isEarly: actualMinutes < normalEndMinutes,
  };
}

function buildCheckoutEvidence({ validation, eventTime, eventId, admin }) {
  return {
    permissionId: validation.permissionId,
    permissionStatusAtCheckout: validation.requestStatus,
    requestedMinutes: validation.requestedMinutes,
    requestedCheckoutMinutes: validation.requestedCheckoutMinutes,
    normalCheckoutMinutes: validation.normalEndMinutes,
    actualCheckoutAt: admin.firestore.Timestamp.fromDate(eventTime),
    checkoutEventId: String(eventId || ''),
    potentialDayFraction: validation.potentialDayFraction,
    gatewayRevision: 1,
    validatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function consequenceFrom({ permissionId, permission, attendanceId, evidence, user, admin }) {
  const fraction = Number(evidence.potentialDayFraction || earlyLeaveFraction(permission.durationMinutes));
  const workDays = Math.max(1, Number(user.payrollWorkDaysPerMonth || 26));
  const amount = (Math.max(0, Number(user.baseMonthlySalary || 0)) / workDays) * fraction;
  return {
    consequenceId: `early_leave_rejection:${permissionId}`,
    attendanceId,
    checkoutEventId: String(evidence.checkoutEventId || ''),
    actualCheckoutAt: evidence.actualCheckoutAt || null,
    executionDate: String(permission.requestDate || ''),
    requestedMinutes: Number(permission.durationMinutes || evidence.requestedMinutes || 0),
    dayFraction: fraction,
    amount,
    currency: String(user.salaryCurrency || 'EGP'),
    reasonCode: 'rejected_early_leave_used',
    reasonLabel: `خصم مغادرة مبكرة بعد رفض الإذن (${Number(permission.durationMinutes || 0) / 60} ساعة)`,
    rejectionReason: String(permission.reviewerComment || permission.managerReviewerComment || permission.hrReviewerComment || ''),
    requestRejectedBy: String(permission.finalApproverId || permission.reviewedBy || ''),
    requestRejectedAt: permission.finalApprovalAt || permission.reviewedAt || admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending_hr',
    reconciliationState: 'complete',
    revision: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function reconcileEarlyLeave({ admin, permissionId }) {
  const db = admin.firestore();
  const permissionRef = db.collection('permissions').doc(permissionId);
  const result = await db.runTransaction(async (transaction) => {
    const permissionSnap = await transaction.get(permissionRef);
    if (!permissionSnap.exists) return { status: 'not_found' };
    const permission = permissionSnap.data() || {};
    if (permission.permissionType !== 'early_leave') return { status: 'not_applicable' };
    const attendanceId = `${permission.userId}_${permission.requestDate}`;
    const attendanceRef = db.collection('attendance').doc(attendanceId);
    const attendanceSnap = await transaction.get(attendanceRef);
    const evidence = attendanceSnap.data()?.earlyLeaveCheckoutEvidence;
    if (!attendanceSnap.exists || !evidence || evidence.permissionId !== permissionId) {
      return { status: 'not_used' };
    }
    const existing = permission.rejectionConsequence;
    if (permission.status === 'approved') {
      if (existing && ['pending_hr', 'approved'].includes(existing.status)) {
        transaction.set(permissionRef, {
          rejectionConsequence: {
            ...existing,
            status: 'reversed',
            reconciliationState: 'complete',
            reversedReason: 'permission_approved',
            revisedAt: admin.firestore.FieldValue.serverTimestamp(),
            revision: Number(existing.revision || 1) + 1,
          },
        }, { merge: true });
      }
      return { status: 'authorized' };
    }
    if (permission.status !== 'rejected') {
      transaction.set(permissionRef, {
        rejectionConsequence: {
          ...(existing || {}),
          reconciliationState: 'pending',
          attendanceId,
        },
      }, { merge: true });
      return { status: 'pending_decision' };
    }
    if (existing && ['approved', 'rejected', 'reversed', 'pending_hr'].includes(existing.status)) {
      return {
        status: existing.status === 'pending_hr' ? 'consequence_pending_hr' : existing.status,
        consequenceId: existing.consequenceId,
        dayFraction: existing.dayFraction,
      };
    }
    const userRef = db.collection('users').doc(permission.userId);
    const userSnap = await transaction.get(userRef);
    const consequence = consequenceFrom({
      permissionId, permission, attendanceId, evidence,
      user: userSnap.data() || {}, admin,
    });
    transaction.set(permissionRef, { rejectionConsequence: consequence }, { merge: true });
    return {
      status: 'consequence_pending_hr',
      consequenceId: consequence.consequenceId,
      dayFraction: consequence.dayFraction,
    };
  });
  await notifyHrReviewers({ admin, permissionId, result });
  return result;
}

function canReviewConsequence(actor) {
  const role = String(actor?.role || '').toLowerCase();
  if (['super_admin', 'admin', 'administrator', 'owner', 'hr', 'hr_admin', 'hr_manager'].includes(role)) {
    return true;
  }
  const scope = [actor?.department, actor?.position, actor?.jobTitle]
    .filter(Boolean).join(' ').toLowerCase();
  return /(^|\s)hr([_\s-]|$)/.test(scope) || scope.includes('human resource') ||
    scope.includes('الموارد البشرية') || scope.includes('موارد بشرية') ||
    scope.includes('شؤون العاملين');
}

function notificationRef(db, recipientId, notificationId) {
  const parent = db.collection('notifications').doc(recipientId);
  return typeof parent.collection === 'function'
    ? parent.collection('items').doc(notificationId)
    : null;
}

async function queueNotification({ admin, recipientId, notificationId, type, title, body, data }) {
  if (!recipientId) return;
  const db = admin.firestore();
  const ref = notificationRef(db, recipientId, notificationId);
  if (!ref) return;
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(ref)).exists) return;
    transaction.set(ref, {
      notificationId, type, title, body, data,
      isRead: false, pushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const increment = admin.firestore.FieldValue.increment;
    if (typeof increment === 'function') {
      transaction.set(db.collection('users').doc(recipientId), {
        unreadNotifications: increment(1),
      }, { merge: true });
    }
  });
}

async function notifyHrReviewers({ admin, permissionId, result }) {
  if (result.status !== 'consequence_pending_hr') return;
  try {
    const usersCollection = admin.firestore().collection('users');
    if (typeof usersCollection.where !== 'function') return;
    const snapshot = await usersCollection.where('isActive', '==', true).limit(100).get();
    const reviewers = snapshot.docs.filter((doc) => canReviewConsequence(doc.data() || {}));
    await Promise.all(reviewers.map((doc) => queueNotification({
      admin,
      recipientId: doc.id,
      notificationId: `early-leave-review-${permissionId}-${doc.id}`,
      type: 'early_leave_deduction_review',
      title: 'خصم مغادرة مبكرة يحتاج قراراً',
      body: `يوجد خصم ${Number(result.dayFraction || 0)} يوم بانتظار مراجعة الموارد البشرية.`,
      data: {
        type: 'early_leave_deduction_review',
        permissionId,
        requestId: permissionId,
        category: 'salary_deductions',
        route: `/manager/requests?category=salary_deductions&requestId=${encodeURIComponent(permissionId)}`,
      },
    })));
  } catch (error) {
    console.error('Early-leave HR notification failed:', {
      permissionId,
      code: String(error?.code || 'notification_failed'),
    });
  }
}

async function reviewEarlyLeaveConsequence({ admin, actor, permissionId, decision }) {
  if (!canReviewConsequence(actor)) {
    const error = new Error('Not authorized to review this deduction.');
    error.code = 'not_authorized';
    throw error;
  }
  if (!['approved', 'rejected'].includes(decision)) {
    const error = new Error('Review decision is invalid.');
    error.code = 'invalid_request';
    throw error;
  }
  const db = admin.firestore();
  const ref = db.collection('permissions').doc(permissionId);
  let recipientId = '';
  const result = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const permission = snap.data() || {};
    recipientId = String(permission.userId || '');
    const existing = permission.rejectionConsequence;
    if (snap.exists && existing && existing.status === decision) {
      return { status: decision, consequenceId: existing.consequenceId };
    }
    if (!snap.exists || !existing || existing.status !== 'pending_hr') {
      const error = new Error('Deduction is not awaiting HR review.');
      error.code = 'invalid_state';
      throw error;
    }
    const next = {
      ...existing,
      status: decision,
      reviewedBy: actor.uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reconciliationState: 'complete',
      revision: Number(existing.revision || 1) + 1,
    };
    transaction.set(ref, { rejectionConsequence: next }, { merge: true });
    const auditId = `early-leave-review-${permissionId}-${Number(existing.revision || 1) + 1}`;
    transaction.set(db.collection('auditLogs').doc(auditId), {
      action: 'early_leave_rejection_consequence_reviewed',
      actorId: actor.uid,
      targetCollection: 'permissions',
      targetId: permissionId,
      decision,
      consequenceId: next.consequenceId,
      previousStatus: existing.status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { status: decision, consequenceId: next.consequenceId };
  });
  await queueNotification({
    admin,
    recipientId,
    notificationId: `early-leave-decision-${permissionId}-${result.status}`,
    type: `early_leave_deduction_${result.status}`,
    title: result.status === 'approved' ? 'تم اعتماد خصم المغادرة المبكرة' : 'تم إلغاء خصم المغادرة المبكرة',
    body: result.status === 'approved'
      ? 'اعتمدت الموارد البشرية خصم المغادرة المبكرة المرفوضة.'
      : 'رفضت الموارد البشرية خصم المغادرة المبكرة.',
    data: {
      type: `early_leave_deduction_${result.status}`,
      permissionId,
      requestId: permissionId,
      category: 'salary_deductions',
      route: '/employee/deductions',
    },
  }).catch((error) => console.error('Early-leave employee notification failed:', {
    permissionId,
    code: String(error?.code || 'notification_failed'),
  }));
  return result;
}

async function reconcilePendingEarlyLeaves({ admin, limit = 50 }) {
  const db = admin.firestore();
  const snapshot = await db.collection('permissions')
    .where('rejectionConsequence.reconciliationState', '==', 'pending')
    .limit(Math.max(1, Math.min(100, Number(limit) || 50)))
    .get();
  let processed = 0;
  let failed = 0;
  for (const doc of snapshot.docs) {
    try {
      await reconcileEarlyLeave({ admin, permissionId: doc.id });
      processed += 1;
    } catch (error) {
      failed += 1;
      console.error('Early-leave reconciliation failed:', {
        permissionId: doc.id,
        code: String(error.code || 'reconciliation_failed'),
      });
    }
  }
  return { found: snapshot.size, processed, failed };
}

module.exports = {
  ALLOWED_STATUSES,
  earlyLeaveFraction,
  validateEarlyLeaveForCheckout,
  buildCheckoutEvidence,
  consequenceFrom,
  reconcileEarlyLeave,
  reviewEarlyLeaveConsequence,
  canReviewConsequence,
  notifyHrReviewers,
  reconcilePendingEarlyLeaves,
};
