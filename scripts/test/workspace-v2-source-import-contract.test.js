const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('V2 source import uses a controller-only safe endpoint', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );
  assert.match(source, /async function handleCompanyWorkspaceV2SourceImport/);
  assert.match(source, /\/company-workspace\/v2\/access\/import/);
  assert.match(source, /workspaceSafeError\(error, \{ writeMayHaveStarted: true \}\)/);
  assert.match(source, /workspaceImportRuns/);
  assert.match(source, /state: 'failed_retryable'/);
  assert.match(source, /syncCompanyWorkspaceIndex\(actor, \{ onProgress: updateProgress \}\)/);
});
