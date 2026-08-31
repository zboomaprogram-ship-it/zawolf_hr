const MAX_VIEWPORT_ROWS = 200;
const MAX_VIEWPORT_COLUMNS = 50;

function asBoundedInteger(value, fallback, max) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1 || number > max) return fallback;
  return number;
}

function validateViewport(input = {}) {
  const startRow = asBoundedInteger(input.startRow, 1, 100000);
  const startColumn = asBoundedInteger(input.startColumn, 1, 702);
  const rowCount = asBoundedInteger(input.rowCount, 50, MAX_VIEWPORT_ROWS);
  const columnCount = asBoundedInteger(input.columnCount, 20, MAX_VIEWPORT_COLUMNS);
  return { startRow, startColumn, rowCount, columnCount };
}

function verifyExpectedSpreadsheetVersion(expectedVersion, actualVersion) {
  const expected = String(expectedVersion || '').trim();
  const actual = String(actualVersion || '').trim();
  if (!expected || !actual || expected === actual) return;
  const error = new Error('Spreadsheet version conflict.');
  error.statusCode = 409;
  throw error;
}

function safeSpreadsheetSnapshot(raw = {}) {
  const tabs = Array.isArray(raw.tabs) ? raw.tabs.map((value) => String(value).slice(0, 100)) : [];
  const safeCell = (cell = {}) => ({
    rawValue: String(cell.rawValue ?? '').slice(0, 10000),
    formattedValue: String(cell.formattedValue ?? '').slice(0, 10000),
    note: String(cell.note ?? '').slice(0, 5000),
    hyperlink: String(cell.hyperlink ?? '').slice(0, 2000),
    backgroundColor: typeof cell.backgroundColor === 'string' ? cell.backgroundColor.slice(0, 16) : null,
    textColor: typeof cell.textColor === 'string' ? cell.textColor.slice(0, 16) : null,
    bold: cell.bold === true,
    italic: cell.italic === true,
    validationType: String(cell.validationType ?? '').slice(0, 80),
    validationValues: Array.isArray(cell.validationValues)
      ? cell.validationValues.slice(0, 100).map((value) => String(value).slice(0, 500)) : [],
  });
  const rows = Array.isArray(raw.rows) ? raw.rows.slice(0, MAX_VIEWPORT_ROWS).map((row) => {
    if (Array.isArray(row)) return row.slice(0, MAX_VIEWPORT_COLUMNS).map((cell) => String(cell ?? '').slice(0, 10000));
    const values = row?.values && typeof row.values === 'object'
      ? Object.fromEntries(Object.entries(row.values).slice(0, MAX_VIEWPORT_COLUMNS)
        .map(([key, value]) => [String(key).slice(0, 500), String(value ?? '').slice(0, 10000)])) : {};
    const cells = row?.cells && typeof row.cells === 'object'
      ? Object.fromEntries(Object.entries(row.cells).slice(0, MAX_VIEWPORT_COLUMNS)
        .map(([key, value]) => [String(key).slice(0, 500), safeCell(value)])) : {};
    return { rowNumber: Number(row?.rowNumber) || 0, values, cells };
  }) : [];
  return {
    tabName: String(raw.tabName || '').slice(0, 100),
    tabs,
    headers: Array.isArray(raw.headers) ? raw.headers.map((value) => String(value).slice(0, 500)) : [],
    headerCells: Array.isArray(raw.headerCells) ? raw.headerCells.slice(0, MAX_VIEWPORT_COLUMNS).map(safeCell) : [],
    rows,
    version: String(raw.version || 'v1').slice(0, 160),
    capabilities: raw.capabilities || { edit: false, structure: false, format: false },
    compatibility: raw.compatibility || 'fullyEditable',
    viewport: raw.viewport || null,
    merges: Array.isArray(raw.merges) ? raw.merges.slice(0, 200) : [],
  };
}

module.exports = {
  MAX_VIEWPORT_ROWS,
  MAX_VIEWPORT_COLUMNS,
  validateViewport,
  verifyExpectedSpreadsheetVersion,
  safeSpreadsheetSnapshot,
};
