'use strict';

// Qualification records are server-only. A record is evidence supplied by the
// qualification process, never a user agent, role label, or client assertion.
const PROFILE_IDS = new Set(['hr_approved_passkey']);
const SAFE_VERSION = /^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$/;

function unqualified() {
  const error = new Error('credential_unqualified');
  error.code = 'credential_unqualified';
  error.messageAr = 'لم يتم تأهيل طريقة التحقق للعمل عن بُعد بعد. تواصل مع مسؤول النظام.';
  return error;
}

async function readQualifiedProfile({ transaction, db, companyId, policy, now, requiredAt = now }) {
  if (policy?.enabled !== true) return null;
  const profileId = policy.devices?.verificationProfile;
  if (!PROFILE_IDS.has(profileId) || !(now instanceof Date) || !Number.isFinite(now.getTime()) ||
      !(requiredAt instanceof Date) || !Number.isFinite(requiredAt.getTime())) throw unqualified();
  const snapshot = await transaction.get(db.collection('remoteWorkQualifiedProfiles').doc(`${companyId}_${profileId}`));
  if (!snapshot.exists) throw unqualified();
  const value = snapshot.data() || {};
  const verifiedAt = Date.parse(value.verifiedAt);
  const expiresAt = value.expiresAt == null ? null : Date.parse(value.expiresAt);
  let origin;
  try { origin = new URL(value.origin); } catch (_) { throw unqualified(); }
  const rpId = typeof value.rpId === 'string' ? value.rpId : '';
  if (value.companyId !== companyId || value.profileId !== profileId || value.status !== 'qualified' ||
      !Number.isSafeInteger(value.version) || value.version < 1 || !Number.isFinite(verifiedAt) || verifiedAt > now.getTime() ||
      (expiresAt !== null && (!Number.isFinite(expiresAt) || expiresAt <= requiredAt.getTime())) ||
      typeof value.library !== 'string' || !value.library.trim() || !SAFE_VERSION.test(String(value.libraryVersion || '')) ||
      origin.protocol !== 'https:' || origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash ||
      !/^[a-z0-9.-]+$/.test(rpId) || !(origin.hostname === rpId || origin.hostname.endsWith(`.${rpId}`))) {
    throw unqualified();
  }
  return { profileId, version: value.version, origin: origin.origin, rpId,
    library: value.library, libraryVersion: value.libraryVersion,
    verifiedAt: value.verifiedAt, expiresAt: value.expiresAt ?? null };
}

function qualificationMatches(left, right) {
  const fields = ['profileId', 'version', 'origin', 'rpId', 'library', 'libraryVersion', 'verifiedAt', 'expiresAt'];
  return Boolean(left && right && fields.every((key) => Object.hasOwn(left, key) && Object.hasOwn(right, key) && left[key] === right[key]));
}

module.exports = { readQualifiedProfile, qualificationMatches, unqualified };
