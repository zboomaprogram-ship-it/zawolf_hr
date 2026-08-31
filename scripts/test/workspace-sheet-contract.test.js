const test = require('node:test');
const assert = require('node:assert/strict');
const { validateViewport, verifyExpectedSpreadsheetVersion, safeSpreadsheetSnapshot } = require('../workspace/spreadsheet-read');
const { normalizeCells, performSpreadsheetMutation } = require('../workspace/spreadsheet-mutations');
const { normalizeStructurePayload, normalizeTabPayload, normalizeFormatPayload, performSpreadsheetFormat } = require('../workspace/spreadsheet-structure');

test('viewport reads are bounded before a provider request', () => {
  assert.deepEqual(validateViewport({ startRow: 2, startColumn: 3, rowCount: 999, columnCount: 999 }), {
    startRow: 2, startColumn: 3, rowCount: 50, columnCount: 20,
  });
});

test('sheet contract exposes only bounded display data and capabilities', () => {
  const snapshot = safeSpreadsheetSnapshot({
    tabName: 'Sheet1', tabs: ['Sheet1', 'Sheet2'],
    headers: ['record_id'], rows: [['A1']], version: 'v2',
    capabilities: { edit: true, structure: true, format: true },
  });
  assert.equal(snapshot.tabName, 'Sheet1');
  assert.equal(snapshot.rows[0][0], 'A1');
  assert.equal(snapshot.capabilities.edit, true);
});

test('a future paste or format request cannot silently claim an unsupported sheet is editable', () => {
  const snapshot = safeSpreadsheetSnapshot({ compatibility: 'unsupportedReadOnly' });
  assert.equal(snapshot.compatibility, 'unsupportedReadOnly');
  assert.equal(snapshot.capabilities.edit, false);
});

test('batched cell editing validates coordinates, avoids duplicate targets, and preserves formulas', async () => {
  const changes = normalizeCells([
    { row: 2, column: 3, value: '=SUM(A1:A2)' },
    { row: 3, column: 3, value: 'نص' },
  ]);
  assert.equal(changes[0].value, '=SUM(A1:A2)');
  assert.throws(() => normalizeCells([
    { row: 2, column: 3, value: 'A' }, { row: 2, column: 3, value: 'B' },
  ]), /invalid/i);
  const calls = [];
  const result = await performSpreadsheetMutation({
    connector: { async updateWorkspaceSheetCells(value) { calls.push(value); } },
    spreadsheetId: 'sheet', tabName: 'Sheet1', kind: 'sheetPaste', payload: { cells: changes },
  });
  assert.equal(result.action, 'sheet_paste');
  assert.equal(calls[0].cells.length, 2);
});

test('row, column, and tab lifecycle payloads are constrained before provider calls', () => {
  assert.deepEqual(normalizeStructurePayload({ operation: 'insert_column', index: 4, count: 2, headerValue: 'اسم' }), {
    operation: 'insert_column', index: 4, count: 2, headerRow: 1, headerValue: 'اسم',
  });
  assert.deepEqual(normalizeTabPayload({ operation: 'add', newName: 'متابعة' }), {
    operation: 'add', tabName: '', newName: 'متابعة',
  });
  assert.throws(() => normalizeTabPayload({ operation: 'delete' }), /invalid/i);
  assert.deepEqual(normalizeStructurePayload({
    operation: 'sort_range', startRow: 2, endRow: 10, startColumn: 1, endColumn: 4, sortColumn: 2, descending: true,
  }), {
    operation: 'sort_range', startRow: 2, endRow: 10, startColumn: 1, endColumn: 4, sortColumn: 2, descending: true,
  });
});

test('formatting, labels, and checkbox validation use a constrained range', async () => {
  const format = normalizeFormatPayload({
    startRow: 2, startColumn: 2, endColumn: 4, backgroundColor: '#123456',
    dropdownValues: ['جديد', 'مكتمل'],
  });
  assert.equal(format.dropdownValues.length, 2);
  const calls = [];
  const result = await performSpreadsheetFormat({
    connector: { async formatWorkspaceSheetRange(value) { calls.push(value); } },
    spreadsheetId: 'sheet', tabName: 'Sheet1', payload: { startRow: 2, startColumn: 2, checkbox: true },
  });
  assert.equal(result.action, 'sheet_format');
  assert.equal(calls[0].checkbox, true);
  assert.throws(() => normalizeFormatPayload({ startRow: 1, startColumn: 1, backgroundColor: 'red' }), /invalid/i);
});

test('safe viewport output keeps cell metadata while bounding arbitrary workbook data', () => {
  const snapshot = safeSpreadsheetSnapshot({
    headers: ['اسم'],
    rows: [{ rowNumber: 5, values: { اسم: 'ندى' }, cells: { اسم: { rawValue: 'ندى', note: 'ملاحظة' } } }],
    headerCells: [{ rawValue: 'اسم', bold: true }],
  });
  assert.equal(snapshot.rows[0].cells.اسم.note, 'ملاحظة');
  assert.equal(snapshot.headerCells[0].bold, true);
});

test('a stale expected viewport version becomes a conflict before mutation', () => {
  assert.doesNotThrow(() => verifyExpectedSpreadsheetVersion('same', 'same'));
  assert.throws(
    () => verifyExpectedSpreadsheetVersion('before', 'after'),
    (error) => error.statusCode === 409,
  );
});
