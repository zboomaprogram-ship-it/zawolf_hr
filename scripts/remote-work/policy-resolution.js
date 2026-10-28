'use strict';

const crypto = require('node:crypto');

const SCOPE_ORDER = ['company', 'department', 'team', 'employee'];
const UNSAFE_KEYS = new Set(['__proto__', 'constructor', 'prototype']);
const SHARED_FIELDS = {
  startTime: 'defaultStartTime',
  endTime: 'defaultEndTime',
  checkInOpenTime: 'checkInOpenTime',
  latestCheckoutTime: 'latestCheckoutTime',
  graceMinutes: 'graceMinutes',
  quarterDayUntilMinutes: 'quarterDayUntilMinutes',
  halfDayUntilMinutes: 'halfDayUntilMinutes',
};

function clone(value) {
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, nested]) => [key, clone(nested)]));
  }
  return value;
}

function assertSafeKeys(value) {
  if (!value || typeof value !== 'object') return;
  for (const [key, nested] of Object.entries(value)) {
    if (UNSAFE_KEYS.has(key)) throw policyError('invalid_policy');
    assertSafeKeys(nested);
  }
}

function mergePolicy(target, source) {
  assertSafeKeys(source);
  for (const [key, value] of Object.entries(source || {})) {
    if (Array.isArray(value)) {
      target[key] = clone(value);
    } else if (value && typeof value === 'object') {
      if (value.mode === 'inherit') continue;
      if (value.mode === 'override') {
        target[key] = clone(value);
      } else {
        target[key] = mergePolicy(
          target[key] && typeof target[key] === 'object' && !Array.isArray(target[key])
            ? target[key]
            : {},
          value,
        );
      }
    } else {
      target[key] = value;
    }
  }
  return target;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
  );
}

function applySharedAttendance(policy, shared = {}) {
  policy.schedule ||= {};
  for (const [remoteKey, sharedKey] of Object.entries(SHARED_FIELDS)) {
    const value = policy.schedule[remoteKey];
    if (!value || value.mode === 'inherit') {
      if (shared[sharedKey] !== undefined) policy.schedule[remoteKey] = shared[sharedKey];
    } else if (value.mode === 'override') {
      policy.schedule[remoteKey] = value.value;
    }
  }
  return policy;
}

function orderScopes(scopes) {
  const byType = new Map();
  for (const entry of scopes || []) {
    if (!SCOPE_ORDER.includes(entry.scope)) throw policyError('unsupported_policy_scope');
    if (byType.has(entry.scope)) throw policyError('policy_scope_ambiguous');
    byType.set(entry.scope, entry);
  }
  if (!byType.has('company')) throw policyError('remote_policy_missing');
  return SCOPE_ORDER.filter((scope) => byType.has(scope)).map((scope) => byType.get(scope));
}

function resolveRemotePolicy({ sharedAttendancePolicy = {}, scopes = [], datedException = null }) {
  const ordered = orderScopes(scopes);
  assertSafeKeys(sharedAttendancePolicy);
  for (const entry of ordered) assertSafeKeys(entry.policy);
  if (datedException) assertSafeKeys(datedException.policy);
  let resolved = {};
  const sourceRevisionIds = [];
  for (const entry of ordered) {
    resolved = mergePolicy(resolved, entry.policy || {});
    if (entry.revisionId) sourceRevisionIds.push(entry.revisionId);
  }
  if (datedException) {
    resolved = mergePolicy(resolved, datedException.policy || {});
    if (datedException.revisionId) sourceRevisionIds.push(datedException.revisionId);
  }
  resolved = applySharedAttendance(resolved, sharedAttendancePolicy);
  const canonicalPolicy = canonicalize(resolved);
  const hash = crypto.createHash('sha256').update(JSON.stringify(canonicalPolicy)).digest('hex');
  return {
    policy: canonicalPolicy,
    sourceRevisionIds,
    hash,
  };
}

function previewRemotePolicy({ sharedAttendancePolicy = {}, scopes = [], datedException = null, candidate }) {
  const current = resolveRemotePolicy({ sharedAttendancePolicy, scopes, datedException });
  const proposedScopes = scopes.filter((entry) => entry.scope !== candidate.scope);
  proposedScopes.push(candidate);
  const proposed = resolveRemotePolicy({ sharedAttendancePolicy, scopes: proposedScopes, datedException });
  return {
    current,
    proposed,
    changed: current.hash !== proposed.hash,
  };
}

function policyError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

module.exports = { resolveRemotePolicy, previewRemotePolicy, mergePolicy };
