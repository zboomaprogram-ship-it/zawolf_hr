'use strict';

const crypto = require('node:crypto');
const { isoDate } = require('./eligibility');
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const ACTIONS = new Set(['check_in', 'check_out', 'save_plan', 'submit_update', 'save_summary']);

function invalid() {
  const error = new Error('invalid_command');
  error.code = 'invalid_command';
  throw error;
}

function canonicalJson(value, ancestors = new Set(), depth = 0) {
  if (depth > 32) invalid();
  if (value === null || typeof value === 'boolean' || typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) invalid();
    return JSON.stringify(value);
  }
  if (typeof value !== 'object' || ancestors.has(value)) invalid();
  if (!Array.isArray(value) && Object.getPrototypeOf(value) !== Object.prototype) invalid();
  ancestors.add(value);
  let result;
  if (Array.isArray(value)) {
    if (Object.keys(value).length !== value.length ||
        Array.from({ length: value.length }, (_, index) => Object.hasOwn(value, index)).some(present => !present)) invalid();
    result = `[${value.map(item => canonicalJson(item, ancestors, depth + 1)).join(',')}]`;
  } else {
    result = `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(value[key], ancestors, depth + 1)}`).join(',')}}`;
  }
  ancestors.delete(value);
  return result;
}

// Business identity deliberately excludes the operation ID and ephemeral proof.
// The action handler must separately validate the payload against its command schema
// and scope the receipt by company and actor before trusting this digest.
function hashRemoteOperation(command) {
  if (!command || !ACTIONS.has(command.kind) || !isoDate(command.date) ||
      !SAFE_ID.test(String(command.operationId || '')) ||
      (command.sessionId != null && !SAFE_ID.test(String(command.sessionId))) ||
      (command.expectedVersion != null && (!Number.isSafeInteger(command.expectedVersion) || command.expectedVersion < 0)) ||
      !command.payload || Object.getPrototypeOf(command.payload) !== Object.prototype) invalid();
  const body = { kind: command.kind, date: command.date, sessionId: command.sessionId ?? null,
    expectedVersion: command.expectedVersion ?? null, payload: command.payload };
  const serialized = canonicalJson(body);
  if (Buffer.byteLength(serialized, 'utf8') > 65536) invalid();
  return crypto.createHash('sha256').update(serialized).digest('hex');
}
module.exports = { hashRemoteOperation };
