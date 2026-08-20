// Server-authoritative check-out policy. This module deliberately defaults to
// disabled so an absent/malformed configuration can never create a checkout
// or a payroll consequence.

const POLICY_COLLECTION = 'publicConfig';
const POLICY_DOCUMENT = 'checkoutPolicy';
const EVENTS_COLLECTION = 'events';
const MANAGER_ROLES = new Set(['hr', 'hr_admin', 'hr_manager', 'super_admin']);

function asBoolean(value) {
  return value === true;
}

function asRevision(value) {
  return Number.isInteger(value) && value >= 0 ? value : 0;
}

function normalizePolicy(data) {
  return {
    enabled: asBoolean(data?.enabled),
    revision: asRevision(data?.revision),
    effectiveAt: data?.effectiveAt || null,
    changedByUserId: typeof data?.changedByUserId === 'string' ? data.changedByUserId : null,
    changedByRole: typeof data?.changedByRole === 'string' ? data.changedByRole : null,
    reason: typeof data?.reason === 'string' ? data.reason : null,
  };
}

function canManageCheckoutPolicy(actor) {
  return Boolean(actor?.uid) && MANAGER_ROLES.has(String(actor.role || '').trim().toLowerCase());
}

function checkoutDisabledResult({ attendanceId, policy }) {
  return {
    action: 'check_out',
    status: 'checkout_disabled',
    attendanceId,
    messageAr: 'تسجيل الانصراف غير مفعّل حالياً. تم حفظ حضورك ولا يلزم إجراء إضافي.',
    policy: {
      enabled: false,
      revision: policy.revision,
      evaluatedAt: new Date().toISOString(),
    },
  };
}

function policyRef(db) {
  return db.collection(POLICY_COLLECTION).doc(POLICY_DOCUMENT);
}

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value.toDate === 'function') return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  const parsed = new Date(value).getTime();
  return Number.isNaN(parsed) ? null : parsed;
}

async function loadCheckoutPolicy(db) {
  const snapshot = await policyRef(db).get();
  return normalizePolicy(snapshot.exists ? snapshot.data() : null);
}

// Payroll must use the policy that was effective for the attendance event, not
// the policy in force when a nightly job happens to be re-run.  Events are
// append-only; if their history cannot be read we fail closed (disabled).
async function resolveCheckoutPolicyAt(db, effectiveAt) {
  const cutoff = timestampMillis(effectiveAt);
  if (cutoff == null) return loadCheckoutPolicy(db);
  const ref = policyRef(db);
  try {
    const events = await ref.collection(EVENTS_COLLECTION)
      .where('effectiveAt', '<=', new Date(cutoff))
      .orderBy('effectiveAt', 'desc')
      .limit(1)
      .get();
    if (!events.empty) return normalizePolicy(events.docs[0].data());

    // Supports a safely-created policy document from before event logging was
    // introduced. It is valid only when it already existed at the cutoff.
    const current = await ref.get();
    const policy = normalizePolicy(current.exists ? current.data() : null);
    const policyAt = timestampMillis(policy.effectiveAt);
    return policyAt != null && policyAt <= cutoff ? policy : normalizePolicy(null);
  } catch (error) {
    console.warn('Could not resolve historical checkout policy; failing closed.', error?.message || error);
    return normalizePolicy(null);
  }
}

async function updateCheckoutPolicy({ db, admin, actor, enabled, expectedRevision, reason = '' }) {
  if (!canManageCheckoutPolicy(actor)) {
    const error = new Error('لا تملك صلاحية التحكم في تسجيل الانصراف.');
    error.code = 'not_authorized';
    throw error;
  }
  if (typeof enabled !== 'boolean') {
    const error = new Error('حالة تسجيل الانصراف غير صحيحة.');
    error.code = 'invalid_request';
    throw error;
  }
  const safeReason = String(reason || '').trim().slice(0, 500);
  const ref = policyRef(db);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = normalizePolicy(snapshot.exists ? snapshot.data() : null);
    if (expectedRevision != null && Number(expectedRevision) !== previous.revision) {
      const error = new Error('تم تغيير حالة تسجيل الانصراف. حدّث الصفحة ثم أعد المحاولة.');
      error.code = 'policy_conflict';
      throw error;
    }
    const revision = previous.revision + 1;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const current = {
      enabled,
      revision,
      effectiveAt: now,
      changedByUserId: actor.uid,
      changedByRole: String(actor.role || ''),
      reason: safeReason || null,
      updatedAt: now,
    };
    const eventRef = ref.collection(EVENTS_COLLECTION).doc();
    transaction.set(ref, current, { merge: true });
    transaction.set(eventRef, {
      ...current,
      previousEnabled: previous.enabled,
      source: 'hr_dashboard',
    });
  });
  // Server timestamps are resolved only after the transaction commits. Read
  // once so HR sees the authoritative effective time rather than a placeholder.
  return loadCheckoutPolicy(db);
}

module.exports = {
  normalizePolicy,
  canManageCheckoutPolicy,
  checkoutDisabledResult,
  loadCheckoutPolicy,
  resolveCheckoutPolicyAt,
  updateCheckoutPolicy,
};
