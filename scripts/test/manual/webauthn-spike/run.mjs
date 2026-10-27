import http from 'node:http';
import { chromium } from 'playwright';
import { generateRegistrationOptions, verifyRegistrationResponse, generateAuthenticationOptions, verifyAuthenticationResponse } from '@simplewebauthn/server';

const browserPath = process.env.WEBAUTHN_BROWSER_PATH;
if (!browserPath) throw new Error('WEBAUTHN_BROWSER_PATH must point to the local Chrome or Brave executable.');
const server = http.createServer((_, res) => { res.setHeader('content-type', 'text/html'); res.end('<!doctype html><title>local credential test</title>'); });
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const origin = `http://localhost:${server.address().port}`;
let browser;
const output = { platform: process.platform, authenticator: 'virtual_ctap2', node: process.version, library: '@simplewebauthn/server@14.0.3', origin, relyingPartyId: 'localhost' };
try {
  browser = await chromium.launch({ executablePath: browserPath, headless: true, args: ['--no-proxy-server'] });
  output.browser = browser.version();
  const page = await browser.newPage();
  await page.goto(origin);
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('WebAuthn.enable');
  const { authenticatorId } = await cdp.send('WebAuthn.addVirtualAuthenticator', { options: {
    protocol: 'ctap2', transport: 'internal', hasResidentKey: true, hasUserVerification: true,
    isUserVerified: true, automaticPresenceSimulation: true,
    defaultBackupEligibility: true, defaultBackupState: true,
  } });
  const creation = await generateRegistrationOptions({ rpName: 'Local ZaWolf test', rpID: 'localhost', userName: 'fixture',
    userID: new TextEncoder().encode('fixture-user'), attestationType: 'none',
    authenticatorSelection: { residentKey: 'required', userVerification: 'required' } });
  const registrationResponse = await page.evaluate(async (options) => {
    const credential = await navigator.credentials.create({ publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options) });
    return credential.toJSON();
  }, creation);
  const registrationArgs = { response: registrationResponse, expectedChallenge: creation.challenge, expectedOrigin: origin,
    expectedRPID: 'localhost', requireUserVerification: true };
  const registration = await verifyRegistrationResponse(registrationArgs);
  output.registrationVerified = registration.verified;
  output.deviceType = registration.registrationInfo?.credentialDeviceType;
  output.backedUp = registration.registrationInfo?.credentialBackedUp;
  const wrongRegistrationOrigin = await verifyRegistrationResponse({ ...registrationArgs, expectedOrigin: 'https://wrong.example' }).then((r) => !r.verified, () => true);
  output.wrongRegistrationOriginRejected = wrongRegistrationOrigin;
  const credential = registration.registrationInfo.credential;
  const request = await generateAuthenticationOptions({ rpID: 'localhost', userVerification: 'required',
    allowCredentials: [{ id: credential.id, transports: ['internal'] }] });
  const response = await page.evaluate(async (options) => {
    const result = await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) });
    return result.toJSON();
  }, request);
  const args = { response, expectedChallenge: request.challenge, expectedOrigin: origin, expectedRPID: 'localhost',
    credential, requireUserVerification: true };
  const verify = async (input) => verifyAuthenticationResponse(input).then((r) => r.verified, () => false);
  output.authenticationVerified = await verify(args);
  output.wrongChallengeRejected = !(await verify({ ...args, expectedChallenge: creation.challenge }));
  output.wrongOriginRejected = !(await verify({ ...args, expectedOrigin: 'https://wrong.example' }));
  output.wrongRpIdRejected = !(await verify({ ...args, expectedRPID: 'wrong.example' }));
  const tampered = structuredClone(response);
  const signature = Buffer.from(tampered.response.signature, 'base64url');
  signature[signature.length - 1] ^= 1;
  tampered.response.signature = signature.toString('base64url');
  output.tamperedSignatureRejected = !(await verify({ ...args, response: tampered }));
  output.replayAcceptedWithoutApplicationChallengeStore = await verify(args);
  await cdp.send('WebAuthn.setUserVerified', { authenticatorId, isUserVerified: false });
  const noUvRequest = await generateAuthenticationOptions({ rpID: 'localhost', userVerification: 'discouraged',
    allowCredentials: [{ id: credential.id, transports: ['internal'] }] });
  const noUvResponse = await page.evaluate(async (options) => {
    const result = await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) });
    return result.toJSON();
  }, noUvRequest);
  output.missingUserVerificationRejected = !(await verify({ ...args, response: noUvResponse, expectedChallenge: noUvRequest.challenge }));
  if (![output.registrationVerified, output.wrongRegistrationOriginRejected, output.authenticationVerified,
    output.wrongChallengeRejected, output.wrongOriginRejected, output.wrongRpIdRejected,
    output.tamperedSignatureRejected, output.replayAcceptedWithoutApplicationChallengeStore,
    output.missingUserVerificationRejected, output.deviceType === 'multiDevice', output.backedUp === true].every(Boolean)) {
    process.exitCode = 1;
  }
} catch (error) {
  output.error = `${error.name}: ${error.message}`;
  process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  await new Promise((resolve) => server.close(resolve));
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
}
