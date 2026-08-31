const test = require('node:test');
const assert = require('node:assert/strict');
const {
  sanitizeDiagnosticEvent,
  diagnosticFingerprint,
  recordDiagnosticEvent,
} = require('../diagnostics');

function fakeFirestore() {
  const documents = new Map();
  const db = {
    collection(name) {
      return {
        doc(id) {
          const key = `${name}/${id}`;
          return { key };
        },
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          const value = documents.get(ref.key);
          return { exists: value !== undefined, data: () => value };
        },
        set(ref, value, options) {
          const previous = documents.get(ref.key) || {};
          documents.set(ref.key, options?.merge ? { ...previous, ...value } : value);
        },
      };
      return callback(transaction);
    },
  };
  return { db, documents };
}

test('diagnostics reject unknown fields and redact sensitive metadata', () => {
  const event = sanitizeDiagnosticEvent({
    feature: 'attendance_checkin',
    safeCode: 'temporarily_unavailable',
    release: '1.2.3+4',
    metadata: { surface: 'home', email: 'person@example.com', state: 'token=private' },
  });
  assert.deepEqual(event.metadata, { surface: 'home' });
  assert.equal(JSON.stringify(event).includes('person@example.com'), false);
  assert.equal(JSON.stringify(event).includes('private'), false);
});

test('diagnostic fingerprints are stable for the same sanitized event', () => {
  const event = sanitizeDiagnosticEvent({
    feature: 'attendance_checkin', safeCode: 'access_denied', release: '1',
  });
  assert.equal(diagnosticFingerprint(event), diagnosticFingerprint(event));
});

test('diagnostics reject unsupported feature and code', () => {
  assert.equal(sanitizeDiagnosticEvent({ feature: 'firebase', safeCode: 'stack_trace' }), null);
});

test('diagnostic aggregation deduplicates by fingerprint and rate limits one actor', async () => {
  const store = fakeFirestore();
  const input = {
    feature: 'attendance_checkin',
    safeCode: 'temporarily_unavailable',
    release: '7.0.0',
    metadata: { surface: 'home', operation: 'submit' },
  };
  const first = await recordDiagnosticEvent(store.db, input, {
    actorId: 'private-actor',
    now: new Date('2026-08-23T10:00:00Z'),
  });
  const throttled = await recordDiagnosticEvent(store.db, input, {
    actorId: 'private-actor',
    now: new Date('2026-08-23T10:00:30Z'),
  });
  const acceptedLater = await recordDiagnosticEvent(store.db, input, {
    actorId: 'private-actor',
    now: new Date('2026-08-23T10:01:01Z'),
  });
  assert.equal(first.accepted, true);
  assert.equal(throttled.accepted, false);
  assert.equal(acceptedLater.accepted, true);
  const aggregate = store.documents.get(`diagnosticAggregates/${first.fingerprint}`);
  assert.equal(aggregate.count, 2);
  assert.equal(JSON.stringify(aggregate).includes('private-actor'), false);
});

test('diagnostics never retain technical provider text in allowlisted values', () => {
  const event = sanitizeDiagnosticEvent({
    feature: 'request_visibility',
    safeCode: 'access_denied',
    release: 'release/with spaces',
    metadata: {
      state: '[cloud_firestore/permission-denied] stack=/private/path',
      operation: 'load',
    },
  });
  assert.deepEqual(event.metadata, { operation: 'load' });
  assert.equal(event.release, 'releasewithspaces');
});
