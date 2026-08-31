const crypto = require('crypto');

const ALLOWED_FEATURES = new Set([
  'attendance_checkin',
  'employee_operations',
  'request_visibility',
  'sales_indicators',
  'notification_operations',
  'required_update',
  'company_workspace',
]);
const ALLOWED_CODES = new Set([
  'session_expired',
  'access_denied',
  'temporarily_unavailable',
  'connection_interrupted',
  'already_submitted',
  'validation_failed',
  'check_request_status',
  'unexpected',
]);
const ALLOWED_METADATA = new Set(['surface', 'platform', 'operation', 'state']);
const SENSITIVE = /(token|secret|password|credential|authorization|email|uid|path|url|stack|exception|firestore)/i;

function safeIdentifier(value, fallback) {
  const result = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .slice(0, 64);
  return result || fallback;
}

function sanitizeDiagnosticEvent(input = {}) {
  const feature = safeIdentifier(input.feature, 'unknown');
  const safeCode = safeIdentifier(input.safeCode, 'unexpected');
  if (!ALLOWED_FEATURES.has(feature) || !ALLOWED_CODES.has(safeCode)) return null;
  const release = String(input.release || 'unknown').replace(/[^A-Za-z0-9._+-]/g, '').slice(0, 80) || 'unknown';
  const metadata = {};
  for (const [key, value] of Object.entries(input.metadata || {})) {
    const text = String(value || '');
    if (ALLOWED_METADATA.has(key) && !SENSITIVE.test(key) && !SENSITIVE.test(text)) {
      metadata[key] = text.slice(0, 80);
    }
  }
  return { feature, safeCode, release, metadata };
}

function diagnosticFingerprint(event) {
  return crypto
    .createHash('sha256')
    .update(`${event.feature}|${event.safeCode}|${event.release}|${JSON.stringify(event.metadata)}`)
    .digest('hex')
    .slice(0, 32);
}

/// Writes only safe aggregate counters. Rate limiting is per actor and
/// fingerprint; the actor ID is intentionally not stored in the aggregate.
async function recordDiagnosticEvent(db, input, {
  actorId,
  now = new Date(),
  minIntervalMs = 60 * 1000,
} = {}) {
  const event = sanitizeDiagnosticEvent(input);
  if (!event || !actorId) return { accepted: false, reason: 'invalid' };
  const fingerprint = diagnosticFingerprint(event);
  const throttleRef = db.collection('diagnosticRateLimits').doc(
    crypto.createHash('sha256').update(`${actorId}|${fingerprint}`).digest('hex').slice(0, 32),
  );
  const aggregateRef = db.collection('diagnosticAggregates').doc(fingerprint);
  let result = { accepted: false, reason: 'rate_limited', fingerprint };
  await db.runTransaction(async (transaction) => {
    const throttle = await transaction.get(throttleRef);
    const aggregate = await transaction.get(aggregateRef);
    const lastAt = throttle.exists ? Date.parse(throttle.data().lastAt || '') : 0;
    if (Number.isFinite(lastAt) && now.getTime() - lastAt < minIntervalMs) return;
    transaction.set(throttleRef, { lastAt: now.toISOString() }, { merge: true });
    transaction.set(aggregateRef, {
      ...event,
      fingerprint,
      count: Number(aggregate.data()?.count || 0) + 1,
      lastSeenAt: now.toISOString(),
    }, { merge: true });
    result = { accepted: true, fingerprint };
  });
  return result;
}

module.exports = { sanitizeDiagnosticEvent, diagnosticFingerprint, recordDiagnosticEvent };
