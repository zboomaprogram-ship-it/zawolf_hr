'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createChallenge, generateAuthenticationOptions, verifyRemoteProof, generateRegistrationOptions, verifyRemoteRegistration } = require('../remote-work/device-credentials');
const qualification = { version: 3, origin: 'https://zawolf-hr-system-60317.web.app', rpId: 'zawolf-hr-system-60317.web.app' };
const now = new Date('2026-11-02T08:00:30.000Z');
const challengeValue = createChallenge();
const challenge = { id: 'challenge1', challenge: challengeValue, credentialId: 'credential1', origin: qualification.origin,
  rpId: qualification.rpId, profileVersion: 3, createdAt: '2026-11-02T08:00:00.000Z', ttlSeconds: 120, expiresAt: '2026-11-02T08:02:00.000Z', consumedAt: null, actorId: 'employee1' };
const credential = { credentialId: 'credential1', publicKey: Buffer.from([1, 2, 3]), counter: 0, state: 'active', transports: ['internal'] };
function fakeWebAuthn(overrides = {}) {
  return {
    generateAuthenticationOptions: async options => ({ ...options, challenge: options.challenge }),
    generateRegistrationOptions: async options => ({ ...options, challenge: options.challenge }),
    verifyAuthenticationResponse: async options => {
      assert.equal(options.expectedChallenge, challengeValue);
      assert.equal(options.expectedOrigin, qualification.origin);
      assert.equal(options.expectedRPID, qualification.rpId);
      assert.equal(options.requireUserVerification, true);
      return { verified: true, authenticationInfo: { userVerified: true, newCounter: 4, credentialDeviceType: 'multiDevice', credentialBackedUp: true }, ...overrides.authentication };
    },
    verifyRegistrationResponse: async options => {
      assert.equal(options.expectedChallenge, challengeValue);
      assert.equal(options.requireUserVerification, true);
      return { verified: true, registrationInfo: { userVerified: true, credential: { id: 'new-id', publicKey: new Uint8Array([8, 9]), counter: 0 }, credentialDeviceType: 'multiDevice', credentialBackedUp: true }, ...overrides.registration };
    },
  };
}
test('challenge values use 32 bytes of random entropy', () => {
  const value = createChallenge();
  assert.equal(Buffer.from(value, 'base64url').length, 32);
});
test('authentication options require the one active approved credential and user verification', async () => {
  const options = await generateAuthenticationOptions({ credential, qualification, challenge: challengeValue, webauthn: fakeWebAuthn() });
  assert.equal(options.rpID, qualification.rpId);
  assert.deepEqual(options.allowCredentials, [{ id: 'credential1', transports: ['internal'] }]);
  await assert.rejects(generateAuthenticationOptions({ credential: { ...credential, state: 'revoked' }, qualification, challenge: challengeValue, webauthn: fakeWebAuthn() }), { code: 'credential_revoked' });
});
test('assertion verification requires valid bound challenge, origin, RP, active credential and UV', async () => {
  const result = await verifyRemoteProof({ assertion: { id: 'credential1' }, challenge, credential, qualification, now, webauthn: fakeWebAuthn() });
  assert.equal(result.verified, true);
  assert.equal(result.newCounter, 4);
  assert.equal(result.deviceType, 'multiDevice');
  assert.equal(result.backedUp, true);
  await assert.rejects(verifyRemoteProof({ assertion: { id: 'credential2' }, challenge, credential, qualification, now, webauthn: fakeWebAuthn() }), { code: 'invalid_challenge_proof' });
  await assert.rejects(verifyRemoteProof({ assertion: { id: 'credential1' }, challenge, credential, qualification: { ...qualification, origin: 'https://evil.test' }, now, webauthn: fakeWebAuthn() }), { code: 'credential_unqualified' });
  await assert.rejects(verifyRemoteProof({ assertion: { id: 'credential1' }, challenge: { ...challenge, expiresAt: now.toISOString() }, credential, qualification, now, webauthn: fakeWebAuthn() }), { code: 'invalid_challenge_proof' });
  await assert.rejects(verifyRemoteProof({ assertion: { id: 'credential1' }, challenge, credential, qualification, now, webauthn: fakeWebAuthn({ authentication: { authenticationInfo: { userVerified: false } } }) }), { code: 'user_verification_required' });
});
test('registration excludes existing credentials and requires an active employee', async () => {
  const user = { uid: 'employee1', isActive: true, email: 'employee@example.test', displayName: 'Employee' };
  const options = await generateRegistrationOptions({ user, qualification, credentials: [credential], challenge: challengeValue, webauthn: fakeWebAuthn() });
  assert.equal(options.rpID, qualification.rpId);
  assert.equal(options.authenticatorSelection.userVerification, 'required');
  assert.deepEqual(options.excludeCredentials, [{ id: 'credential1', transports: ['internal'] }]);
  await assert.rejects(generateRegistrationOptions({ user: { ...user, isActive: false }, qualification, challenge: challengeValue, webauthn: fakeWebAuthn() }), { code: 'invalid_enrollment' });
});
test('registration verification returns only a public key and credential metadata', async () => {
  const result = await verifyRemoteRegistration({ response: { id: 'new-id', response: { transports: ['internal'] } }, user: { uid: 'employee1', isActive: true }, qualification, challenge, now, webauthn: fakeWebAuthn() });
  assert.deepEqual(result.publicKey, Buffer.from([8, 9]));
  assert.equal(result.credentialId, 'new-id');
  assert.equal(result.backedUp, true);
  assert.equal(result.profileVersion, 3);
  assert.equal(result.createdAt, now.toISOString());
});
