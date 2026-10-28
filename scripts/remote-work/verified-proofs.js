'use strict';
const verifiedProofs = new WeakSet();
function markVerifiedProof(value) {
  if (!value || typeof value !== 'object') throw new TypeError('Verified proof must be an object.');
  const proof = Object.freeze({ ...value });
  verifiedProofs.add(proof);
  return proof;
}
function isVerifiedProof(value) { return Boolean(value && typeof value === 'object' && verifiedProofs.has(value)); }
module.exports = { markVerifiedProof, isVerifiedProof };
