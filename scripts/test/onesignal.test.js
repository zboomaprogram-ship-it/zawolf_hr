'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { formatOneSignalAuthHeader, buildPushPayload } = require('../onesignal');

test('formatOneSignalAuthHeader prefixes app key with Basic', () => {
  assert.equal(
    formatOneSignalAuthHeader('os_v2_app_abcdef123456'),
    'Basic os_v2_app_abcdef123456',
  );
  assert.equal(
    formatOneSignalAuthHeader('MzRlNjU0ZGMtOGYyYS00...'),
    'Basic MzRlNjU0ZGMtOGYyYS00...',
  );
});

test('formatOneSignalAuthHeader preserves already-prefixed Basic and Key headers', () => {
  assert.equal(
    formatOneSignalAuthHeader('Basic MzRlNjU0ZGMtOGYyYS00...'),
    'Basic MzRlNjU0ZGMtOGYyYS00...',
  );
  assert.equal(
    formatOneSignalAuthHeader('basic os_v2_app_123'),
    'basic os_v2_app_123',
  );
  assert.equal(
    formatOneSignalAuthHeader('Key os_v2_org_xyz'),
    'Key os_v2_org_xyz',
  );
});

test('formatOneSignalAuthHeader prefixes org key with Key', () => {
  assert.equal(
    formatOneSignalAuthHeader('os_v2_org_xyz123'),
    'Key os_v2_org_xyz123',
  );
});

test('formatOneSignalAuthHeader handles empty or null key safely', () => {
  assert.equal(formatOneSignalAuthHeader(''), '');
  assert.equal(formatOneSignalAuthHeader(null), '');
  assert.equal(formatOneSignalAuthHeader(undefined), '');
});


test('push payload lets each installed Android app choose its own valid channel', () => {
  const payload = buildPushPayload(['employee-1'], 'عنوان', 'نص', { route: '/notifications' });
  assert.equal('android_channel_id' in payload, false);
  assert.equal(payload.ios_sound, 'notification_chime.wav');
  assert.deepEqual(payload.include_aliases, { external_id: ['employee-1'] });
});
