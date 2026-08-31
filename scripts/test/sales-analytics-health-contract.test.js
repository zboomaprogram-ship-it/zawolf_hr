'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const server = fs.readFileSync(path.join(__dirname, '..', 'notification-web.js'), 'utf8');

test('health exposes safe sales integration readiness without a provider key', () => {
  assert.match(server, /function salesAnalyticsHealth\(\)/);
  assert.match(server, /salesAnalytics: salesAnalyticsHealth\(\)/);
  assert.match(server, /configured: Boolean\(process\.env\.SALES_API_KEY\)/);
  assert.match(server, /lastSyncStatus/);
  assert.doesNotMatch(server, /apiKey:\s*process\.env\.SALES_API_KEY/);
});
