function structureValidationError() {
  const error = new Error('Spreadsheet structure change is invalid.');
  error.code = 'validation';
  return error;
}

function normalizeStructurePayload(payload = {}) {
  const operation = String(payload.operation || '').trim();
  if (['set_filter', 'clear_filter', 'sort_range'].includes(operation)) {
    const startRow = Number(payload.startRow);
    const endRow = Number(payload.endRow || payload.startRow);
    const startColumn = Number(payload.startColumn);
    const endColumn = Number(payload.endColumn || payload.startColumn);
    if (operation !== 'clear_filter' &&
        (![startRow, endRow, startColumn, endColumn].every(Number.isInteger) || startRow < 1 ||
        endRow < startRow || startColumn < 1 || endColumn < startColumn || endRow > 100000 || endColumn > 702)) {
      throw structureValidationError();
    }
    return {
      operation,
      startRow,
      endRow,
      startColumn,
      endColumn,
      sortColumn: Number(payload.sortColumn || startColumn),
      descending: payload.descending === true,
    };
  }
  const index = Number(payload.index);
  const count = Number(payload.count || 1);
  if (!['insert_row', 'delete_row', 'insert_column', 'delete_column'].includes(operation) ||
      !Number.isInteger(index) || index < 1 || index > 100000 ||
      !Number.isInteger(count) || count < 1 || count > 100) throw structureValidationError();
  return {
    operation,
    index,
    count,
    headerRow: Math.max(1, Math.min(Number(payload.headerRow) || 1, 50)),
    headerValue: String(payload.headerValue || '').trim().slice(0, 200),
  };
}

function normalizeTabPayload(payload = {}) {
  const operation = String(payload.operation || '').trim();
  if (!['add', 'rename', 'delete'].includes(operation)) throw structureValidationError();
  const tabName = String(payload.tabName || '').trim();
  const newName = String(payload.newName || '').trim();
  if ((operation !== 'add' && !tabName) || (operation !== 'delete' && !newName) ||
      tabName.length > 100 || newName.length > 100) throw structureValidationError();
  return { operation, tabName, newName };
}

function normalizeFormatPayload(payload = {}) {
  const startRow = Number(payload.startRow);
  const endRow = Number(payload.endRow || payload.startRow);
  const startColumn = Number(payload.startColumn);
  const endColumn = Number(payload.endColumn || payload.startColumn);
  if (![startRow, endRow, startColumn, endColumn].every(Number.isInteger) ||
      startRow < 1 || endRow < startRow || startColumn < 1 || endColumn < startColumn ||
      endRow > 100000 || endColumn > 702) throw structureValidationError();
  const dropdownValues = Array.isArray(payload.dropdownValues)
    ? payload.dropdownValues.map((value) => String(value || '').trim()).filter(Boolean).slice(0, 100)
    : undefined;
  if (dropdownValues?.some((value) => value.length > 500)) throw structureValidationError();
  const colors = ['backgroundColor', 'textColor'];
  for (const key of colors) {
    if (payload[key] != null && !/^#[0-9A-Fa-f]{6}$/.test(String(payload[key]))) {
      throw structureValidationError();
    }
  }
  const output = {
    startRow, endRow, startColumn, endColumn,
    backgroundColor: payload.backgroundColor,
    textColor: payload.textColor,
    bold: typeof payload.bold === 'boolean' ? payload.bold : undefined,
    italic: typeof payload.italic === 'boolean' ? payload.italic : undefined,
    horizontalAlignment: payload.horizontalAlignment,
    wrapStrategy: payload.wrapStrategy,
    dropdownValues,
    checkbox: payload.checkbox === true,
    clearValidation: payload.clearValidation === true,
    clearFormatting: payload.clearFormatting === true,
  };
  if (!output.backgroundColor && !output.textColor && output.bold == null && output.italic == null &&
      !output.horizontalAlignment && !output.wrapStrategy && !dropdownValues?.length && !output.checkbox &&
      !output.clearValidation && !output.clearFormatting) throw structureValidationError();
  return output;
}

async function performSpreadsheetStructure({ connector, spreadsheetId, tabName, kind, payload }) {
  if (kind === 'sheetStructure') {
    const change = normalizeStructurePayload(payload);
    if (['set_filter', 'clear_filter', 'sort_range'].includes(change.operation)) {
      await connector.configureWorkspaceSheetFilter({ spreadsheetId, tabName, ...change });
      return { action: 'sheet_structure', result: change, audit: { changeCount: 1 } };
    }
    await connector.changeWorkspaceSheetStructure({ spreadsheetId, tabName, ...change });
    return { action: 'sheet_structure', result: change, audit: { changeCount: change.count } };
  }
  if (kind === 'sheetTab') {
    const change = normalizeTabPayload(payload);
    const result = await connector.changeWorkspaceSheetTab({ spreadsheetId, ...change });
    return { action: 'sheet_tab', result, audit: { changeCount: 1 } };
  }
  throw structureValidationError();
}

async function performSpreadsheetFormat({ connector, spreadsheetId, tabName, payload }) {
  const change = normalizeFormatPayload(payload);
  await connector.formatWorkspaceSheetRange({ spreadsheetId, tabName, ...change });
  return {
    action: 'sheet_format', result: { changedCells: (change.endRow - change.startRow + 1) * (change.endColumn - change.startColumn + 1) },
    audit: { changeCount: 1, range: `${tabName}!${change.startRow}:${change.endRow}` },
  };
}

module.exports = { normalizeStructurePayload, normalizeTabPayload, normalizeFormatPayload, performSpreadsheetStructure, performSpreadsheetFormat };
