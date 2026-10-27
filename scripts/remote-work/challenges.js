'use strict';

const { isoDate } = require('./eligibility');
const { CHALLENGE_TTL_SECONDS } = require('./security-bounds');
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const HASH = /^[a-f0-9]{64}$/;
const ACTIONS = new Set(['check_in', 'check_out', 'save_plan', 'submit_update', 'save_summary']);
function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}

// Server-only transaction primitive: proof must be the trusted result of actual
// cryptographic verification, never the client assertion or a client boolean.
// Call only after all other Firestore reads in the surrounding action transaction.
// The action's writes must be made in this same transaction, otherwise consuming
// the challenge separately can strand an operation. This is not an HTTP handler.
async function consumeVerifiedChallenge({ db, transaction, actor, command, proof, now }) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) fail('invalid_server_time');
  if (actor?.active !== true || !SAFE_ID.test(String(actor.uid || '')) ||
      !SAFE_ID.test(String(actor.companyId || '')) || !SAFE_ID.test(String(proof?.challengeId || '')) ||
      !SAFE_ID.test(String(proof?.credentialId || '')) || !SAFE_ID.test(String(command?.operationId || '')) ||
      !ACTIONS.has(command?.kind) || !HASH.test(String(command?.payloadHash || '')) || !isoDate(command?.date) ||
      proof?.verified !== true || typeof proof.challenge !== 'string' || !proof.challenge) fail('invalid_challenge_proof');
  const ref = db.collection('remoteWorkChallenges').doc(proof.challengeId);
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists) fail('challenge_not_found');
  const stored = snapshot.data() || {};
  if (stored.consumedAt != null) fail('challenge_consumed');
  const created = Date.parse(stored.createdAt);
  const expires = Date.parse(stored.expiresAt);
  if (!Number.isSafeInteger(stored.ttlSeconds) || stored.ttlSeconds < CHALLENGE_TTL_SECONDS.min || stored.ttlSeconds > CHALLENGE_TTL_SECONDS.max ||
      !Number.isFinite(created) || !Number.isFinite(expires) || expires - created !== stored.ttlSeconds * 1000 ||
      created > now.getTime() || expires <= now.getTime()) fail('challenge_expired');
  if (stored.companyId !== actor.companyId || stored.actorId !== actor.uid || stored.action !== command.kind ||
      stored.operationId !== command.operationId || stored.payloadHash !== command.payloadHash || stored.date !== command.date ||
      stored.credentialId !== proof.credentialId || stored.challenge !== proof.challenge ||
      !Number.isSafeInteger(stored.version) || stored.version < 1) fail('invalid_challenge_proof');
  transaction.set(ref, { ...stored, consumedAt: now.toISOString(), version: stored.version + 1 });
  return { challengeId: proof.challengeId, version: stored.version + 1 };
}
module.exports = { consumeVerifiedChallenge };
