'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryBackend } = require('./helpers/remote-work-fixtures');
const { consumeVerifiedChallenge } = require('../remote-work/challenges');
const { markVerifiedProof } = require('../remote-work/verified-proofs');

const now = new Date('2026-11-02T08:00:00.000Z');
const actor = { uid: 'employee1', companyId: 'company1', active: true };
const command = { operationId: 'operation1', kind: 'check_in', payloadHash: 'a'.repeat(64), date: '2026-11-02' };
const proof = markVerifiedProof({ challengeId: 'challenge1', credentialId: 'credential1', verified: true, challenge: 'random-value' });
function fixture() {
  const f = createMemoryBackend();
  f.seed('remoteWorkChallenges', 'challenge1', { companyId: 'company1', actorId: 'employee1', action: 'check_in',
    operationId: 'operation1', payloadHash: command.payloadHash, date: command.date, credentialId: 'credential1',
    challenge: 'random-value', createdAt: '2026-11-02T08:00:00.000Z', ttlSeconds: 120, expiresAt: '2026-11-02T08:02:00.000Z', consumedAt: null, version: 1 });
  return f;
}
async function consume(f, overrides = {}) {
  return f.db.runTransaction(async transaction => {
    const result = await consumeVerifiedChallenge({ db: f.db, transaction, actor, command, proof, now, ...overrides });
    transaction.set(f.db.collection('testAttendance').doc('day'), { recorded: true });
    return result;
  });
}
test('a verified challenge is consumed in the same transaction as the action', async () => {
  const f = fixture();
  await consume(f);
  assert.equal(f.read('remoteWorkChallenges', 'challenge1').consumedAt, now.toISOString());
  assert.equal(f.read('testAttendance', 'day').recorded, true);
  await assert.rejects(consume(f), { code: 'challenge_consumed' });
});
test('concurrent action attempts cannot both consume one challenge', async () => {
  const f = fixture();
  const results = await Promise.allSettled([consume(f), consume(f)]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.filter(r => r.status === 'rejected')[0].reason.code, 'challenge_consumed');
});
test('transaction failure rolls back both consumption and action', async () => {
  const f = fixture();
  await assert.rejects(f.db.runTransaction(async transaction => {
    await consumeVerifiedChallenge({ db: f.db, transaction, actor, command, proof, now });
    throw new Error('abort');
  }), /abort/);
  assert.equal(f.read('remoteWorkChallenges', 'challenge1').consumedAt, null);
});
for (const [label, overrides] of [
  ['wrong company', { actor: { ...actor, companyId: 'company2' } }],
  ['wrong actor', { actor: { ...actor, uid: 'employee2' } }],
  ['wrong action', { command: { ...command, kind: 'check_out' } }],
  ['wrong operation', { command: { ...command, operationId: 'operation2' } }],
  ['wrong payload', { command: { ...command, payloadHash: 'b'.repeat(64) } }],
  ['wrong day', { command: { ...command, date: '2026-11-03' } }],
  ['wrong credential', { proof: { ...proof, credentialId: 'credential2' } }],
  ['wrong challenge', { proof: { ...proof, challenge: 'other' } }],
  ['unverified proof', { proof: { ...proof, verified: false } }],
  ['expired challenge', { now: new Date('2026-11-02T08:02:00.000Z') }],
]) test(`${label} cannot consume the challenge`, async () => {
  const f = fixture();
  await assert.rejects(consume(f, overrides));
  assert.equal(f.read('remoteWorkChallenges', 'challenge1').consumedAt, null);
  assert.equal(f.read('testAttendance', 'day'), null);
});

for (const [label, patch] of [
  ['missing creation time', { createdAt: null }],
  ['future creation time', { createdAt: '2026-11-02T08:00:01.000Z' }],
  ['lifetime exceeding server security limit', { ttlSeconds: 301, expiresAt: '2026-11-02T08:05:01.000Z' }],
  ['malformed expiry', { expiresAt: 'not-a-date' }],
]) test(`${label} cannot consume the challenge`, async () => {
  const f = fixture();
  f.seed('remoteWorkChallenges', 'challenge1', { ...f.read('remoteWorkChallenges', 'challenge1'), ...patch });
  await assert.rejects(consume(f), { code: 'challenge_expired' });
  assert.equal(f.read('testAttendance', 'day'), null);
});

test('Firestore contention commits one challenge use and one action', {
  skip: process.env.RUN_REMOTE_WORK_EMULATOR !== '1',
}, async () => {
  const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
  const harness = await createRemoteHarness({ backend: 'emulator' });
  const challengeId = `race_${Date.now()}`;
  const raceProof = markVerifiedProof({ ...proof, challengeId });
  try {
    await harness.seed('remoteWorkChallenges', challengeId, {
      companyId: actor.companyId, actorId: actor.uid, action: command.kind, operationId: command.operationId,
      payloadHash: command.payloadHash, date: command.date, credentialId: proof.credentialId,
      challenge: proof.challenge, createdAt: now.toISOString(), ttlSeconds: 120, expiresAt: '2026-11-02T08:02:00.000Z', consumedAt: null, version: 1,
    });
    const attempt = id => harness.db.runTransaction(async transaction => {
      await consumeVerifiedChallenge({ db: harness.db, transaction, actor, command, proof: raceProof, now });
      transaction.set(harness.db.collection('testRemoteChallengeActions').doc(`${challengeId}_${id}`), { success: true });
    });
    const results = await Promise.allSettled([attempt('a'), attempt('b')]);
    assert.equal(results.filter(x => x.status === 'fulfilled').length, 1);
    assert.equal(results.find(x => x.status === 'rejected').reason.code, 'challenge_consumed');
    const actions = await Promise.all(['a', 'b'].map(id => harness.read('testRemoteChallengeActions', `${challengeId}_${id}`)));
    assert.equal(actions.filter(Boolean).length, 1);
  } finally { await harness.close(); }
});

test('valid policy may issue a 180-second challenge within server security bounds', async () => {
  const f = fixture();
  f.seed('remoteWorkChallenges', 'challenge1', { ...f.read('remoteWorkChallenges', 'challenge1'), expiresAt: '2026-11-02T08:03:00.000Z', ttlSeconds: 180 });
  await consume(f, { now: new Date('2026-11-02T08:02:30.000Z') });
  assert.equal(f.read('testAttendance', 'day').recorded, true);
});

test('recorded challenge lifetime must match its policy snapshot', async () => {
  const f = fixture();
  f.seed('remoteWorkChallenges', 'challenge1', { ...f.read('remoteWorkChallenges', 'challenge1'), ttlSeconds: 60 });
  await assert.rejects(consume(f), { code: 'challenge_expired' });
  assert.equal(f.read('testAttendance', 'day'), null);
});
