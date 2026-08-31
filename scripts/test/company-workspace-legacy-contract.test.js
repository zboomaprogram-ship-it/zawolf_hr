const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('legacy company workspace endpoints remain characterized for rollback', () => {
  const server = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );
  for (const endpoint of [
    '/company-workspace/discover',
    '/company-workspace/bootstrap',
    '/company-workspace/reports/audit',
  ]) {
    assert.match(server, new RegExp(endpoint.replace(/[/?]/g, '\\$&')));
  }
  assert.match(server, /url\.pathname\.startsWith\(['"]\/company-workspace\/['"]\)/);
});
