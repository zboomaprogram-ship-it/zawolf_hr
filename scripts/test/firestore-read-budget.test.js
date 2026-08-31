const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

function source(name) {
  return fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
}

test('manager bypass scopes pending permissions to the current date', () => {
  const code = source('manager-leave-permission-bypass.js');
  assert.match(
    code,
    /where\(["']status["'], ["']==["'], ["']pending_manager["']\)[\s\S]{0,200}where\(["']requestDate["'], ["']==["'], dateKey\)/,
  );
  assert.match(code, /MANAGER_LEAVE_CACHE_MS/);
});

test('attendance reminder does not re-read one run every five minutes', () => {
  const code = source('attendance-reminders.js');
  assert.match(code, /attemptedReminderRuns/);
  assert.match(code, /attemptedReminderRuns\.ids\.has\(runId\)/);
  assert.match(code, /attemptedReminderRuns\.ids\.add\(runId\)/);
});

test('Workspace V2 foundation does not introduce an unbounded Firestore scan', () => {
  const sourceRoot = path.join(__dirname, '..', 'workspace');
  const files = fs.readdirSync(sourceRoot).filter((file) => file.endsWith('.js'));
  for (const file of files) {
    const code = fs.readFileSync(path.join(sourceRoot, file), 'utf8');
    assert.doesNotMatch(code, /\.collection\([^)]*\)\.get\(\)/);
    assert.doesNotMatch(code, /\.collection\([^)]*\)\.where\([^)]*\)\.get\(\)/);
  }
});

test('Phase 007 diagnostics and sales identity reads have hard caps', () => {
  const server = source('notification-web.js');
  const sales = source('sync-sales-kpis.js');
  assert.match(server, /collection\(['"]diagnosticAggregates['"]\)[\s\S]{0,160}limit\(250\)/);
  assert.match(sales, /collection\(['"]salesIdentityMappings['"]\)[\s\S]{0,160}limit\(500\)/);
});

test('Company OS operations and dashboards cap every Firestore query', () => {
  for (const name of ['company-os/operations.js', 'company-os/dashboard.js']) {
    const code = source(name);
    assert.doesNotMatch(code, /\.collection\([^)]*\)\.get\(\)/);
    assert.doesNotMatch(code, /\.where\([^)]*\)\.get\(\)/);
    assert.match(code, /limit\(/);
  }
  assert.match(source('company-os/operations.js'), /Math\.min\([^\n]*100\)/);
});
