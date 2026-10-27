'use strict';

const crypto = require('node:crypto');
const { CHALLENGE_TTL_SECONDS } = require('./security-bounds');

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}

function webauthnServer(adapter) {
  if (adapter) return adapter;
  if (Number(process.versions.node.split('.')[0]) < 22) fail('webauthn_runtime_unsupported');
  return require('@simplewebauthn/server');
}

function parseQualifiedOrigin(qualification) {
  let origin;
  try { origin = new URL(qualification?.origin); } catch (_) { fail('credential_unqualified'); }
  const localTestOrigin = qualification.localTest === true && origin.protocol === 'http:' && origin.hostname === 'localhost';
  if ((!localTestOrigin && origin.protocol !== 'https:') || origin.origin !== qualification.origin || origin.username || origin.password ||
      origin.pathname !== '/' || origin.search || origin.hash || typeof qualification.rpId !== 'string' ||
      !(origin.hostname === qualification.rpId || origin.hostname.endsWith(`.${qualification.rpId}`))) {
    fail('credential_unqualified');
  }
  return { origin: origin.origin, rpId: qualification.rpId };
}

function createChallenge() {
  return crypto.randomBytes(32).toString('base64url');
}

async function generateAuthenticationOptions({ credential, qualification, challenge, webauthn }) {
  if (!credential || credential.state !== 'active' || typeof credential.credentialId !== 'string' ||
      !credential.credentialId || typeof challenge !== 'string' || challenge.length < 32) fail('credential_revoked');
  const { rpId } = parseQualifiedOrigin(qualification);
  const server = webauthnServer(webauthn);
  const options = await server.generateAuthenticationOptions({
    rpID: rpId,
    challenge: Buffer.from(challenge, 'base64url'),
    allowCredentials: [{ id: credential.credentialId, transports: credential.transports || [] }],
    userVerification: 'required',
  });
  return options;
}

async function verifyRemoteProof({ assertion, challenge, credential, qualification, now = new Date(), webauthn }) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime()) || !credential || credential.state !== 'active' ||
      typeof credential.credentialId !== 'string' || !credential.credentialId || !Buffer.isBuffer(credential.publicKey) &&
      !(credential.publicKey instanceof Uint8Array) || !Number.isSafeInteger(credential.counter) || credential.counter < 0 ||
      typeof challenge?.challenge !== 'string' || !challenge.challenge || challenge.consumedAt != null ||
      !Number.isSafeInteger(challenge.ttlSeconds) || challenge.ttlSeconds < CHALLENGE_TTL_SECONDS.min ||
      challenge.ttlSeconds > CHALLENGE_TTL_SECONDS.max || !Number.isFinite(Date.parse(challenge.createdAt)) ||
      Date.parse(challenge.expiresAt) - Date.parse(challenge.createdAt) !== challenge.ttlSeconds * 1000 ||
      !Number.isFinite(Date.parse(challenge.expiresAt)) || Date.parse(challenge.expiresAt) <= now.getTime() ||
      challenge.credentialId !== credential.credentialId || !assertion || assertion.id !== credential.credentialId) fail('invalid_challenge_proof');
  const { origin, rpId } = parseQualifiedOrigin(qualification);
  if (challenge.origin !== origin || challenge.rpId !== rpId || challenge.profileVersion !== qualification.version) fail('credential_unqualified');
  const server = webauthnServer(webauthn);
  let result;
  try {
    result = await server.verifyAuthenticationResponse({
      response: assertion,
      expectedChallenge: challenge.challenge,
      expectedOrigin: origin,
      expectedRPID: rpId,
      requireUserVerification: true,
      credential: {
        id: credential.credentialId,
        publicKey: new Uint8Array(credential.publicKey),
        counter: credential.counter,
        transports: credential.transports || [],
      },
    });
  } catch (_) { fail('invalid_passkey_assertion'); }
  if (result?.verified !== true || result.authenticationInfo?.userVerified !== true) fail('user_verification_required');
  const info = result.authenticationInfo;
  return Object.freeze({
    verified: true,
    challengeId: challenge.id,
    credentialId: credential.credentialId,
    challenge: challenge.challenge,
    newCounter: Number.isSafeInteger(info.newCounter) ? info.newCounter : credential.counter,
    deviceType: info.credentialDeviceType,
    backedUp: info.credentialBackedUp === true,
    verifiedAt: now.toISOString(),
  });
}

async function generateRegistrationOptions({ user, qualification, credentials = [], challenge, webauthn }) {
  if (!user || typeof user.uid !== 'string' || !user.uid || user.isActive !== true ||
      typeof challenge !== 'string' || challenge.length < 32 || !Array.isArray(credentials) || credentials.length > 3) {
    fail('invalid_enrollment');
  }
  const { rpId } = parseQualifiedOrigin(qualification);
  const server = webauthnServer(webauthn);
  const userID = crypto.createHash('sha256').update(user.uid).digest();
  return server.generateRegistrationOptions({
    rpName: 'ZaWolf HR',
    rpID: rpId,
    userID,
    userName: String(user.email || user.uid),
    userDisplayName: String(user.displayName || user.name || user.uid),
    challenge: Buffer.from(challenge, 'base64url'),
    attestationType: 'none',
    excludeCredentials: credentials.filter(item => item?.state === 'active' && item.credentialId)
      .map(item => ({ id: item.credentialId, transports: item.transports || [] })),
    authenticatorSelection: { residentKey: 'required', userVerification: 'required' },
  });
}

async function verifyRemoteRegistration({ response, user, qualification, challenge, now = new Date(), webauthn }) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime()) || !user || user.isActive !== true || typeof challenge?.challenge !== 'string' || !challenge.challenge ||
      challenge.consumedAt != null || !Number.isSafeInteger(challenge.ttlSeconds) || challenge.ttlSeconds < CHALLENGE_TTL_SECONDS.min ||
      challenge.ttlSeconds > CHALLENGE_TTL_SECONDS.max || !Number.isFinite(Date.parse(challenge.createdAt)) ||
      Date.parse(challenge.expiresAt) - Date.parse(challenge.createdAt) !== challenge.ttlSeconds * 1000 ||
      !Number.isFinite(Date.parse(challenge.expiresAt)) ||
      Date.parse(challenge.expiresAt) <= now.getTime() || challenge.actorId !== user.uid) fail('invalid_enrollment');
  const { origin, rpId } = parseQualifiedOrigin(qualification);
  if (challenge.origin !== origin || challenge.rpId !== rpId || challenge.profileVersion !== qualification.version) fail('credential_unqualified');
  let result;
  try {
    result = await webauthnServer(webauthn).verifyRegistrationResponse({
      response,
      expectedChallenge: challenge.challenge,
      expectedOrigin: origin,
      expectedRPID: rpId,
      requireUserVerification: true,
    });
  } catch (_) { fail('invalid_passkey_registration'); }
  if (result?.verified !== true || result.registrationInfo?.userVerified !== true) fail('user_verification_required');
  const info = result.registrationInfo;
  return Object.freeze({
    credentialId: info.credential.id,
    publicKey: Buffer.from(info.credential.publicKey),
    counter: Number.isSafeInteger(info.credential.counter) ? info.credential.counter : 0,
    transports: Array.isArray(response?.response?.transports) ? response.response.transports : [],
    deviceType: info.credentialDeviceType,
    backedUp: info.credentialBackedUp === true,
    profileVersion: qualification.version,
    createdAt: now.toISOString(),
  });
}

module.exports = { createChallenge, generateAuthenticationOptions, verifyRemoteProof, generateRegistrationOptions, verifyRemoteRegistration };
