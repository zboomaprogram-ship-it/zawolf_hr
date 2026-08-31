const test = require('node:test');
const assert = require('node:assert/strict');
const {
  workspaceSheetCompatibility,
  ensureWorkspaceSheetCompatible,
} = require('../workspace/spreadsheet-compatibility');
const { safeSpreadsheetSnapshot } = require('../workspace/spreadsheet-read');

test('protected and unsupported workbook content is always read-only', () => {
  for (const compatibility of ['protectedReadOnly', 'unsupportedReadOnly']) {
    assert.equal(workspaceSheetCompatibility({ compatibility }), compatibility);
    assert.throws(
      () => ensureWorkspaceSheetCompatible({ compatibility }),
      (error) => error.code === 'unsupported' && error.statusCode === 409,
    );
  }
});

test('unknown compatibility cannot accidentally block a supported workbook', () => {
  assert.equal(workspaceSheetCompatibility({ compatibility: 'future-provider-feature' }), 'fullyEditable');
  assert.doesNotThrow(() => ensureWorkspaceSheetCompatible({ compatibility: 'fullyEditable' }));
});

test('read-only compatibility reaches the client without provider metadata', () => {
  const snapshot = safeSpreadsheetSnapshot({
    tabName: 'Sheet1',
    compatibility: 'protectedReadOnly',
    capabilities: { edit: false, structure: false, format: false },
  });
  assert.equal(snapshot.compatibility, 'protectedReadOnly');
  assert.equal(snapshot.capabilities.edit, false);
});
