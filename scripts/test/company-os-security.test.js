'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { enforceRateLimit, validateAttachmentReferences, redactSensitiveLog, resetRateLimitsForTests } = require('../company-os/security');

test('rate limits are actor and route scoped and reset per window', () => {
  resetRateLimitsForTests();
  enforceRateLimit({ actorUid: 'u1', route: '/company-os/tickets', now: 1, maxRequests: 2, windowMs: 100 });
  enforceRateLimit({ actorUid: 'u1', route: '/company-os/tickets', now: 2, maxRequests: 2, windowMs: 100 });
  assert.throws(() => enforceRateLimit({ actorUid: 'u1', route: '/company-os/tickets', now: 3, maxRequests: 2, windowMs: 100 }), (error) => error.code === 'rate_limited');
  assert.doesNotThrow(() => enforceRateLimit({ actorUid: 'u2', route: '/company-os/tickets', now: 3, maxRequests: 2, windowMs: 100 }));
  assert.doesNotThrow(() => enforceRateLimit({ actorUid: 'u1', route: '/company-os/tickets', now: 102, maxRequests: 2, windowMs: 100 }));
});

test('attachment references are bounded and validated without accepting URLs', () => {
  assert.deepEqual(validateAttachmentReferences({ attachments: [{ id: 'file-1', displayName: 'دليل.pdf', contentType: 'application/pdf', sizeBytes: 100 }] }).length, 1);
  assert.throws(() => validateAttachmentReferences({ attachments: Array.from({ length: 11 }, () => ({})) }), (error) => error.code === 'invalid_input');
  assert.throws(() => validateAttachmentReferences({ attachments: [{ id: 'https://evil.test/file', displayName: 'x', contentType: 'text/plain', sizeBytes: 1 }] }), (error) => error.code === 'invalid_input');
});

test('security log redaction is recursive', () => {
  const safe = redactSensitiveLog({ action: 'create', authorization: 'Bearer secret', nested: { token: 'secret', value: 1 }, privateNotes: ['secret'] });
  assert.deepEqual(safe, { action: 'create', nested: { value: 1 } });
  assert.equal(JSON.stringify(safe).includes('secret'), false);
});
