const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('V2 Drive operations resolve provider IDs only on the server', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );
  const start = source.indexOf('async function executeWorkspaceV2DriveOperation');
  const end = source.indexOf('async function executeWorkspaceV2SpreadsheetOperation', start);
  const implementation = source.slice(start, end);

  assert.ok(start >= 0 && end > start, 'V2 Drive operation boundary is present');
  assert.match(implementation, /workspaceParentFolderId\(item\)/);
  assert.match(implementation, /destinationResourceId/);
  assert.match(implementation, /fileId: item\.externalId/);
  assert.doesNotMatch(implementation, /payload\.path/);
  assert.doesNotMatch(implementation, /payload\.destinationPath/);
  assert.doesNotMatch(implementation, /payload\.fileId/);
});

test('V2 file download identifies the requested internal resource in its URL', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );
  assert.match(source, /company-workspace\\\/v2\\\/resources\\\/\[\^\/\]\+\\\/content/);
  assert.match(source, /fileId: item\.externalId/);
});
