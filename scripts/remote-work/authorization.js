'use strict';

const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

function authorizationError(code, messageAr) {
  const error = new Error(code);
  error.code = code;
  error.messageAr = messageAr;
  return error;
}

function instant(value) {
  if (value?.toDate instanceof Function) return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'string') return Date.parse(value);
  return NaN;
}

function grantIsActive(grant, now) {
  if (grant.status !== 'active' || grant.revokedAt != null || !Array.isArray(grant.capabilities)) return false;
  const start = grant.effectiveFrom == null ? -Infinity : instant(grant.effectiveFrom);
  const end = grant.effectiveUntil == null ? Infinity : instant(grant.effectiveUntil);
  return Number.isFinite(start) || start === -Infinity
    ? (Number.isFinite(end) || end === Infinity) && start <= now && now < end
    : false;
}

async function resolveActorScope({ db, identity, requestedCompanyId, now = new Date() }) {
  const uid = String(identity?.uid || '');
  const companyId = String(requestedCompanyId || '');
  if (!SAFE_ID.test(uid) || !SAFE_ID.test(companyId)) throw authorizationError('invalid_identity');
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) throw authorizationError('invalid_server_time');

  const userSnapshot = await db.collection('users').doc(uid).get();
  if (!userSnapshot.exists || userSnapshot.data()?.isActive !== true) {
    throw authorizationError('account_inactive', 'الحساب غير نشط.');
  }
  const user = userSnapshot.data() || {};
  let membershipConfirmed = false;
  if (typeof user.companyId === 'string' && user.companyId !== companyId) {
    throw authorizationError('wrong_company', 'لا ينتمي الحساب إلى هذه الشركة.');
  }
  if (typeof user.companyId === 'string' && user.companyId === companyId) membershipConfirmed = true;
  if (Array.isArray(user.companyIds) && !user.companyIds.includes(companyId)) {
    throw authorizationError('wrong_company', 'لا ينتمي الحساب إلى هذه الشركة.');
  }
  if (Array.isArray(user.companyIds) && user.companyIds.includes(companyId)) membershipConfirmed = true;

  const grantsSnapshot = await db.collection('remoteWorkCapabilityGrants')
    .where('actorId', '==', uid)
    .where('companyId', '==', companyId)
    .limit(100)
    .get();
  const capabilities = new Set();
  const grantVersions = {};
  const grantIds = {};
  const grantVersionsById = {};
  const scopesByCapability = {};
  for (const document of grantsSnapshot.docs) {
    const grant = document.data() || {};
    if (grant.actorId !== uid || grant.companyId !== companyId || !grantIsActive(grant, now.getTime())) continue;
    membershipConfirmed = true;
    if (!['company', 'department', 'team', 'employee'].includes(grant.scopeType) || !SAFE_ID.test(String(grant.scopeId || ''))) continue;
    for (const capability of grant.capabilities) {
      if (typeof capability !== 'string' || !/^[a-z][a-z0-9_]{1,63}$/.test(capability)) continue;
      scopesByCapability[capability] ||= [];
      scopesByCapability[capability].push({ type: grant.scopeType, id: grant.scopeId, grantId: document.id });
      if (grant.scopeType === 'company' && grant.scopeId === companyId) {
        capabilities.add(capability);
        grantVersions[capability] = Math.max(grantVersions[capability] || 0, Number(grant.version || 0));
        grantIds[capability] = [...new Set([...(grantIds[capability] || []), document.id])];
        grantVersionsById[document.id] = Number(grant.version || 0);
      }
    }
  }
  if (!membershipConfirmed) throw authorizationError('wrong_company', 'لا يوجد سجل عضوية ساري لهذه الشركة.');
  return {
    uid,
    companyId,
    role: String(user.role || ''),
    active: true,
    membershipVersion: Number(user.membershipVersion || 0),
    capabilities: [...capabilities].sort(),
    grantVersions,
    grantIds,
    grantVersionsById,
    scopesByCapability,
  };
}

function hasCapability(actor, capability, { scopeType = 'company', scopeId = actor?.companyId } = {}) {
  if (!actor?.active) return false;
  return (actor.scopesByCapability?.[capability] || []).some((scope) => scope.type === scopeType && scope.id === scopeId);
}

module.exports = { resolveActorScope, hasCapability, grantIsActive };
