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
