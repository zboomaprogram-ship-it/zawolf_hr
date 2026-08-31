'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const server = fs.readFileSync(path.join(__dirname, '..', 'notification-web.js'), 'utf8');

test('HR reports are a protected V2 route using authoritative business dates', () => {
  assert.match(server, /company-workspace\/v2\/reports\/hr/);
  assert.match(server, /canViewWorkspaceHrReports/);
  assert.match(server, /collection\('attendance'\)\.where\('date', '>=', period\.startDate\)/);
  assert.match(server, /collection\('permissions'\)\.where\('requestDate', '>=', period\.startDate\)/);
  assert.match(server, /buildHrOperationalRows/);
  assert.match(server, /reserveWorkspaceReport/);
});
