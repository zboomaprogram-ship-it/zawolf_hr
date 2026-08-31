'use strict';

const SENSITIVE_KEYS = /(?:password|token|authorization|secret|privateNote|privateNotes|stack|rawError)/i;
const DEFAULT_WINDOW_MS = 60_000;
const DEFAULT_MAX_REQUESTS = 120;
const buckets = new Map();

function securityError(code, message) {
  const error = new Error(message); error.code = code; return error;
}

function enforceRateLimit({ actorUid, route, now = Date.now(), maxRequests = DEFAULT_MAX_REQUESTS, windowMs = DEFAULT_WINDOW_MS }) {
  const key = `${String(actorUid).slice(0, 128)}:${String(route).slice(0, 180)}`;
  const current = buckets.get(key);
  if (!current || now - current.startedAt >= windowMs) {
    buckets.set(key, { startedAt: now, count: 1 });
    return;
  }
  current.count += 1;
  if (current.count > maxRequests) throw securityError('rate_limited', 'Rate limited');
}

function validateAttachmentReferences(input) {
  const references = input?.attachments ?? input?.attachmentReferences;
  if (references == null) return [];
  if (!Array.isArray(references) || references.length > 10) throw securityError('invalid_input', 'Invalid attachments');
  return references.map((reference) => {
    if (!reference || typeof reference !== 'object') throw securityError('invalid_input', 'Invalid attachment');
    const id = String(reference.id || '').trim();
    const displayName = String(reference.displayName || '').trim();
    const contentType = String(reference.contentType || '').trim().toLowerCase();
    const sizeBytes = Number(reference.sizeBytes);
    if (!/^[A-Za-z0-9_.:-]{1,256}$/.test(id) || !displayName || displayName.length > 240
      || !/^[a-z0-9.+-]+\/[a-z0-9.+-]+$/.test(contentType)
      || !Number.isSafeInteger(sizeBytes) || sizeBytes < 0 || sizeBytes > 25 * 1024 * 1024) {
      throw securityError('invalid_input', 'Invalid attachment reference');
    }
    return { id, displayName, contentType, sizeBytes };
  });
}

function redactSensitiveLog(value) {
  if (Array.isArray(value)) return value.map(redactSensitiveLog);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !SENSITIVE_KEYS.test(key))
    .map(([key, child]) => [key, redactSensitiveLog(child)]));
}

function resetRateLimitsForTests() { buckets.clear(); }

module.exports = { enforceRateLimit, validateAttachmentReferences, redactSensitiveLog, resetRateLimitsForTests };
