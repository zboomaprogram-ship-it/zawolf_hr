const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isDeveloperToolsExpiryValid,
  isDeveloperToolsEntitlementActive,
  normalizeDeveloperToolScopes,
} = require('../developer-tools-entitlement');

test('developer tools require an explicit short-lived expiry', () => {
  const now = Date.now();
  assert.equal(isDeveloperToolsExpiryValid(new Date(now + 60 * 60 * 1000), now), true);
  assert.equal(isDeveloperToolsExpiryValid(new Date(now - 1), now), false);
  assert.equal(isDeveloperToolsExpiryValid(new Date(now + 8 * 24 * 60 * 60 * 1000), now), false);
});

test('only diagnostic scopes are accepted and no attendance bypass exists', () => {
  assert.deepEqual(
    normalizeDeveloperToolScopes(['app_diagnostics', 'network_diagnostics', 'attendance_bypass']),
    ['app_diagnostics', 'network_diagnostics'],
  );
  assert.deepEqual(normalizeDeveloperToolScopes(['attendance_bypass']), []);
});

test('a permanent entitlement remains limited to diagnostic scopes', () => {
  assert.equal(isDeveloperToolsEntitlementActive({ permanent: true, scopes: ['app_diagnostics'] }), true);
  assert.equal(isDeveloperToolsEntitlementActive({ permanent: true, revokedAt: new Date() }), false);
});
