const MAX_CELL_BATCH = 500;

function spreadsheetValidationError() {
  const error = new Error('Spreadsheet mutation is invalid.');
  error.code = 'validation';
  return error;
}

function normalizeCells(rawCells) {
  if (!Array.isArray(rawCells) || rawCells.length < 1 || rawCells.length > MAX_CELL_BATCH) {
    throw spreadsheetValidationError();
  }
  const seen = new Set();
  return rawCells.map((raw) => {
    const row = Number(raw?.row);
    const column = Number(raw?.column);
    const value = String(raw?.value ?? '');
    if (!Number.isInteger(row) || row < 1 || row > 100000 ||
        !Number.isInteger(column) || column < 1 || column > 702 || value.length > 10000) {
      throw spreadsheetValidationError();
    }
    const key = `${row}:${column}`;
    if (seen.has(key)) throw spreadsheetValidationError();
    seen.add(key);
    return { row, column, value };
  });
}

async function performSpreadsheetMutation({ connector, spreadsheetId, tabName, kind, payload }) {
  if (kind !== 'sheetEdit' && kind !== 'sheetPaste') throw spreadsheetValidationError();
  const cells = normalizeCells(payload?.cells);
  await connector.updateWorkspaceSheetCells({ spreadsheetId, tabName, cells });
  return {
    action: kind === 'sheetPaste' ? 'sheet_paste' : 'sheet_edit',
    result: { changedCells: cells.length },
    audit: { changeCount: cells.length, range: `${tabName}!${cells[0].row}:${cells[cells.length - 1].row}` },
  };
}

module.exports = { MAX_CELL_BATCH, normalizeCells, performSpreadsheetMutation };
