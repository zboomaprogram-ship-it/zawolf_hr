import http from 'node:http';
import { chromium } from 'playwright';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../notification-web.js', import.meta.url));
const device = require('./remote-work/device-credentials.js');
const webauthn = require('@simplewebauthn/server');
const { consumeVerifiedChallenge } = require('./remote-work/challenges.js');
const { createMemoryBackend } = require('./test/helpers/remote-work-fixtures.js');
const browserPath = process.env.WEBAUTHN_BROWSER_PATH;
if (!browserPath) throw new Error('WEBAUTHN_BROWSER_PATH must point to local Chrome or Brave.');
const server = http.createServer((_, res) => { res.setHeader('content-type', 'text/html'); res.end('<title>Local test</title>'); });
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://localhost:${server.address().port}`;
const rp = { version: 3, origin, rpId: 'localhost', localTest: true };
const now = new Date();
const user = { uid: 'fixture_employee', isActive: true, email: 'fixture@example.test', displayName: 'Fixture' };
const output = { platform: process.platform, browser: null, node: process.version, library: '@simplewebauthn/server@14.0.3', origin, rpId: rp.rpId };
let browser;
const stamp = () => ({ createdAt: now.toISOString(), expiresAt: new Date(now.getTime() + 120000).toISOString(), ttlSeconds: 120, consumedAt: null });
try {
  browser = await chromium.launch({ executablePath: browserPath, headless: true, args: ['--no-proxy-server'] });
  output.browser = browser.version();
  const page = await browser.newPage(); await page.goto(origin);
  const cdp = await page.context().newCDPSession(page); await cdp.send('WebAuthn.enable');
  const { authenticatorId } = await cdp.send('WebAuthn.addVirtualAuthenticator', { options: {
    protocol: 'ctap2', transport: 'internal', hasResidentKey: true, hasUserVerification: true,
    isUserVerified: true, automaticPresenceSimulation: true, defaultBackupEligibility: true, defaultBackupState: true,
  } });
  const regValue = device.createChallenge();
  const regChallenge = { ...stamp(), id: 'registration1', actorId: user.uid, challenge: regValue, origin,
    rpId: rp.rpId, profileVersion: rp.version };
  const regOptions = await device.generateRegistrationOptions({ user, qualification: rp, challenge: regValue });
  const regResponse = await page.evaluate(async options => (await navigator.credentials.create({
    publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options) })).toJSON(), regOptions);
  const reg = await device.verifyRemoteRegistration({ response: regResponse, user, qualification: rp, challenge: regChallenge, now });
  output.registrationVerified = Boolean(reg.credentialId && reg.publicKey.length);
  output.deviceType = reg.deviceType; output.backedUp = reg.backedUp;

  const command = { operationId: 'operation1', kind: 'check_in', payloadHash: 'a'.repeat(64), date: '2026-11-02' };
  const challengeValue = device.createChallenge();
  const challenge = { ...stamp(), version: 1, id: 'action1', actorId: user.uid, companyId: 'company1', challenge: challengeValue,
    origin, rpId: rp.rpId, profileVersion: rp.version, credentialId: reg.credentialId, action: command.kind,
    operationId: command.operationId, payloadHash: command.payloadHash, date: command.date };
  const activeCredential = { ...reg, state: 'active' };
  const requestOptions = await device.generateAuthenticationOptions({ credential: activeCredential, qualification: rp, challenge: challengeValue });
  const assertion = await page.evaluate(async options => (await navigator.credentials.get({
    publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) })).toJSON(), requestOptions);
  const proof = await device.verifyRemoteProof({ assertion, challenge, credential: activeCredential, qualification: rp, now });
  output.assertionVerified = proof.verified; output.counter = proof.newCounter;
  const db = createMemoryBackend(); db.seed('remoteWorkChallenges', challenge.id, challenge);
  await db.db.runTransaction(async transaction => {
    await consumeVerifiedChallenge({ db: db.db, transaction, actor: { uid: user.uid, companyId: 'company1', active: true }, command,
      proof: { ...proof, challengeId: challenge.id }, now });
    transaction.set(db.db.collection('remoteWorkTestActions').doc(command.operationId), { success: true });
  });
  output.singleUseConsumed = db.read('remoteWorkChallenges', challenge.id).consumedAt === now.toISOString();
  try {
    await db.db.runTransaction(transaction => consumeVerifiedChallenge({ db: db.db, transaction,
      actor: { uid: user.uid, companyId: 'company1', active: true }, command, proof: { ...proof, challengeId: challenge.id }, now }));
    output.replayRejected = false;
  } catch (error) { output.replayRejected = error.code === 'challenge_consumed'; }

  const noUvChallenge = { ...challenge, id: 'no_uv', challenge: device.createChallenge(), ...stamp() };
  const noUvOptions = await webauthn.generateAuthenticationOptions({ rpID: rp.rpId, challenge: Buffer.from(noUvChallenge.challenge, 'base64url'),
    allowCredentials: [{ id: activeCredential.credentialId, transports: activeCredential.transports || [] }], userVerification: 'discouraged' });
  await cdp.send('WebAuthn.setUserVerified', { authenticatorId, isUserVerified: false });
  try {
    const noUvResponse = await page.evaluate(async options => (await navigator.credentials.get({
      publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) })).toJSON(), noUvOptions);
    try { await device.verifyRemoteProof({ assertion: noUvResponse, challenge: noUvChallenge, credential: activeCredential, qualification: rp, now }); output.missingUvRejected = false; }
    catch (error) { output.missingUvError = error.code || error.name; output.missingUvRejected = ['user_verification_required', 'invalid_passkey_assertion'].includes(error.code); }
  } catch (error) { output.missingUvError = error.name; output.missingUvRejected = error.name === 'NotAllowedError'; }
  if (![output.registrationVerified, output.assertionVerified, output.singleUseConsumed, output.replayRejected, output.backedUp, output.missingUvRejected].every(Boolean)) process.exitCode = 1;
} catch (error) { output.error = `${error.name}: ${error.message}`; process.exitCode = 1; }
finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
}
