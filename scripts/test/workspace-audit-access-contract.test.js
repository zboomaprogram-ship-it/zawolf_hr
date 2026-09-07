const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('HR can generate the governed Workspace audit report but not manage access', () => {
  const server = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );

  assert.match(server, /function canGenerateWorkspaceAuditReport\(actor\)[\s\S]*canViewWorkspaceHrReports\(actor\)/);
  assert.match(server, /isWorkspaceHrActor\(actor\)/);
  assert.match(
    server,
    /handleWorkspaceAuditReport[\s\S]*?canGenerateWorkspaceAuditReport\(actor\)/,
  );
  assert.match(
    server,
    /handleWorkspaceAuditEvents[\s\S]*?canGenerateWorkspaceAuditReport\(actor\)/,
  );
  assert.match(
    server,
    /req\.method !== 'PUT' \|\| !isWorkspaceController\(actor\)/,
  );
});

test('request-management notification audit actions are accepted', () => {
  const { ALLOWED_ACTIONS } = require('../workspace/audit');
  assert.equal(ALLOWED_ACTIONS.has('request_manager_reminder_sent'), true);
  assert.equal(ALLOWED_ACTIONS.has('request_employee_edit_notice_sent'), true);
});
