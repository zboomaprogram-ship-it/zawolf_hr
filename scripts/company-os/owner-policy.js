'use strict';

async function resolveCompanyOwner(db) {
  const policySnapshot = await db.collection('companyOsOwnerPolicies').where('active', '==', true).limit(1).get();
  if (!policySnapshot.empty) {
    const policy = policySnapshot.docs[0].data();
    return { ownerUid: policy.ownerUid, version: Number(policy.version), source: 'managed_policy' };
  }
  const ownerSnapshot = await db.collection('users').where('code', '==', 'ceo-100').where('isActive', '==', true).limit(2).get();
  if (ownerSnapshot.size !== 1) { const error = new Error('Owner unavailable'); error.code = 'owner_unavailable'; throw error; }
  return { ownerUid: ownerSnapshot.docs[0].id, version: 1, source: 'initial_resolution' };
}

async function replaceCompanyOwner({ db, ownerUid, actorUid, operationId, now = new Date() }) {
  if (!ownerUid || !actorUid || !operationId) { const error = new Error('Invalid owner replacement'); error.code = 'invalid_input'; throw error; }
  return db.runTransaction(async (tx) => {
    const receiptRef = db.collection('companyOsOperationReceipts').doc(operationId);
    const existing = await tx.get(receiptRef);
    if (existing.exists) return existing.data().result;
    const activeQuery = db.collection('companyOsOwnerPolicies').where('active', '==', true).limit(2);
    const current = await tx.get(activeQuery);
    const version = current.empty ? 1 : Math.max(...current.docs.map((doc) => Number(doc.data().version || 0))) + 1;
    for (const doc of current.docs) tx.update(doc.ref, { active: false, replacedAt: now, replacedBy: actorUid });
    const policyRef = db.collection('companyOsOwnerPolicies').doc(`owner-policy-v${version}`);
    tx.create(policyRef, { version, ownerUid, active: true, activeFrom: now, createdBy: actorUid });
    const result = { ok: true, operationId, status: 'saved', resourceId: policyRef.id, version };
    tx.create(receiptRef, { actorUid, operationType: 'owner_policy_replace', result, createdAt: now });
    tx.create(db.collection('companyOsAuditEvents').doc(operationId), { operationId, actorUid, action: 'owner_policy_replace', targetType: 'owner_policy', targetId: policyRef.id, safeAfter: { ownerUid, version }, createdAt: now });
    return result;
  });
}

module.exports = { resolveCompanyOwner, replaceCompanyOwner };
