const { GoogleAuth, OAuth2Client } = require('google-auth-library');
const crypto = require('node:crypto');

const SHEETS_SCOPE = 'https://www.googleapis.com/auth/spreadsheets';
const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive';
const SHEETS_API = 'https://sheets.googleapis.com/v4/spreadsheets';
const DRIVE_API = 'https://www.googleapis.com/drive/v3';
const MAX_DRIVE_DOWNLOAD_BYTES = 20 * 1024 * 1024;
const REQUIRED_HEADERS = [
  'record_id',
  'employee_id',
  'employee_name',
  'department',
  'task_name',
  'status',
  'amount',
  'notes',
  'updated_at',
];
const EDITABLE_HEADERS = new Set(['task_name', 'status', 'amount', 'notes']);
const ALLOWED_STATUSES = new Set(['pending', 'in_progress', 'completed']);

function parseServiceAccount(rawValue) {
  if (!rawValue || typeof rawValue !== 'string') {
    throw new Error('GOOGLE_SHEETS_SERVICE_ACCOUNT is missing.');
  }
  try {
    let json = rawValue.trim();
    if (json.startsWith('\\{')) json = json.slice(1);
    json = json.replace(/\\"/g, '"').replace(/\\([^"\\/bfnrtu])/g, '$1');
    const account = JSON.parse(json);
    if (typeof account.private_key === 'string') {
      account.private_key = account.private_key.replace(/\\n/g, '\n');
    }
    if (!account.client_email || !account.private_key || !account.project_id) {
      throw new Error('required service-account fields are missing');
    }
    return account;
  } catch (error) {
    throw new Error(
      `GOOGLE_SHEETS_SERVICE_ACCOUNT is invalid: ${error.message || error}`,
    );
  }
}

function integrationConfig(env = process.env) {
  const spreadsheetId = String(env.GOOGLE_SHEETS_TEST_SPREADSHEET_ID || '').trim();
  const tabName = String(env.GOOGLE_SHEETS_TEST_TAB || 'Employee_Test_Data').trim();
  // The test Sheet is optional. Chat and request attachments only need a
  // governed Drive folder, so do not make their upload path depend on a
  // separate test spreadsheet configuration.
  if (spreadsheetId && !/^[A-Za-z0-9_-]{20,}$/.test(spreadsheetId)) {
    throw new Error('GOOGLE_SHEETS_TEST_SPREADSHEET_ID is invalid.');
  }
  if (!tabName || /[\r\n!]/.test(tabName)) {
    throw new Error('GOOGLE_SHEETS_TEST_TAB is invalid.');
  }
  const folderId = String(env.GOOGLE_DRIVE_TEST_FOLDER_ID || '').trim();
  if (folderId && !/^[A-Za-z0-9_-]{10,}$/.test(folderId)) {
    throw new Error('GOOGLE_DRIVE_TEST_FOLDER_ID is invalid.');
  }
  const reportsSpreadsheetId = String(
    env.GOOGLE_HR_REPORTS_SPREADSHEET_ID || '',
  ).trim();
  if (reportsSpreadsheetId &&
      !/^[A-Za-z0-9_-]{20,}$/.test(reportsSpreadsheetId)) {
    throw new Error('GOOGLE_HR_REPORTS_SPREADSHEET_ID is invalid.');
  }
  const workspaceRootFolderId = String(
    env.GOOGLE_WORKSPACE_ROOT_FOLDER_ID || '',
  ).trim();
  if (workspaceRootFolderId && !/^[A-Za-z0-9_-]{10,}$/.test(workspaceRootFolderId)) {
    throw new Error('GOOGLE_WORKSPACE_ROOT_FOLDER_ID is invalid.');
  }
  return { spreadsheetId, tabName, folderId, reportsSpreadsheetId, workspaceRootFolderId };
}

function quotedTab(tabName) {
  return `'${tabName.replace(/'/g, "''")}'`;
}

function columnName(index) {
  let value = index + 1;
  let result = '';
  while (value > 0) {
    value -= 1;
    result = String.fromCharCode(65 + (value % 26)) + result;
    value = Math.floor(value / 26);
  }
  return result;
}

function mapRows(values) {
  if (!Array.isArray(values) || values.length === 0) return [];
  const headers = values[0].map((value) => String(value || '').trim());
  const missing = REQUIRED_HEADERS.filter((header) => !headers.includes(header));
  if (missing.length > 0) {
    throw new Error(`Sheet is missing required headers: ${missing.join(', ')}`);
  }
  return values.slice(1).flatMap((row, index) => {
    const record = {};
    headers.forEach((header, column) => {
      if (REQUIRED_HEADERS.includes(header)) record[header] = row[column] ?? '';
    });
    if (!String(record.record_id || '').trim()) return [];
    Object.defineProperty(record, '_rowNumber', {
      value: index + 2,
      enumerable: false,
    });
    return [record];
  });
}

function validateUpdate(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new Error('Update body must be a JSON object.');
  }
  const update = {};
  for (const [key, rawValue] of Object.entries(input)) {
    if (!EDITABLE_HEADERS.has(key)) {
      throw new Error(`Field is not editable: ${key}`);
    }
    if (key === 'amount') {
      const amount = Number(rawValue);
      if (!Number.isFinite(amount) || amount < 0) {
        throw new Error('amount must be a non-negative number.');
      }
      update.amount = amount;
      continue;
    }
    const value = String(rawValue ?? '').trim();
    if (value.length > (key === 'notes' ? 1000 : 200)) {
      throw new Error(`${key} is too long.`);
    }
    if (key === 'status' && !ALLOWED_STATUSES.has(value)) {
      throw new Error('status must be pending, in_progress, or completed.');
    }
    if (/^[=+@]/.test(value)) {
      throw new Error(`${key} cannot start with a spreadsheet formula character.`);
    }
    update[key] = value;
  }
  if (Object.keys(update).length === 0) {
    throw new Error('At least one editable field is required.');
  }
  return update;
}

function createGoogleSheetsIntegration({
  env = process.env,
  authClient,
  driveUploadAuthClient,
} = {}) {
  const config = integrationConfig(env);
  const oauthClientId = String(env.GOOGLE_DRIVE_OAUTH_CLIENT_ID || '').trim();
  const oauthClientSecret = String(env.GOOGLE_DRIVE_OAUTH_CLIENT_SECRET || '').trim();
  const oauthRefreshToken = String(env.GOOGLE_DRIVE_OAUTH_REFRESH_TOKEN || '').trim();

  // Reports and Sheets continue to use the restricted service account.  A
  // personal Google Drive can instead provide an OAuth account only for file
  // uploads/downloads, so its storage quota is used without granting it
  // access to HR Sheets APIs.
  let auth;
  if (authClient) {
    auth = authClient;
  } else {
    const credentials = parseServiceAccount(env.GOOGLE_SHEETS_SERVICE_ACCOUNT || '');
    auth = new GoogleAuth({
      credentials,
      scopes: [SHEETS_SCOPE, DRIVE_SCOPE],
    });
  }
  let driveUploadAuth = driveUploadAuthClient || null;
  if (!driveUploadAuth && oauthClientId && oauthClientSecret && oauthRefreshToken) {
    driveUploadAuth = new OAuth2Client(oauthClientId, oauthClientSecret);
    driveUploadAuth.setCredentials({ refresh_token: oauthRefreshToken });
  }
  let cachedRows = null;
  let cacheExpiresAt = 0;

  async function request(options, { useDriveUploadOAuth = false } = {}) {
    const selectedAuth = useDriveUploadOAuth && driveUploadAuth
      ? driveUploadAuth
      : auth;
    const client = typeof selectedAuth.getClient === 'function'
      ? await selectedAuth.getClient()
      : selectedAuth;
    return client.request(options);
  }

  async function readRows({ force = false } = {}) {
    if (!config.spreadsheetId) {
      throw new Error('GOOGLE_SHEETS_TEST_SPREADSHEET_ID is missing.');
    }
    if (!force && cachedRows && Date.now() < cacheExpiresAt) return cachedRows;
    const range = `${quotedTab(config.tabName)}!A1:I`;
    const response = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(config.spreadsheetId)}/values/${encodeURIComponent(range)}`,
      params: { majorDimension: 'ROWS', valueRenderOption: 'FORMATTED_VALUE' },
      retry: true,
    });
    cachedRows = mapRows(response.data?.values || []);
    cacheExpiresAt = Date.now() + 30 * 1000;
    return cachedRows;
  }

  async function updateRow(recordId, rawUpdate) {
    const safeRecordId = String(recordId || '').trim();
    if (!/^[A-Za-z0-9_-]{1,80}$/.test(safeRecordId)) {
      throw new Error('record_id is invalid.');
    }
    const update = validateUpdate(rawUpdate);
    const rows = await readRows();
    const matches = rows.filter((row) => String(row.record_id) === safeRecordId);
    if (matches.length === 0) {
      const error = new Error('record_id was not found.');
      error.code = 'not_found';
      throw error;
    }
    if (matches.length > 1) throw new Error('record_id must be unique in the Sheet.');

    const rowNumber = matches[0]._rowNumber;
    const data = Object.entries(update).map(([header, value]) => {
      const column = columnName(REQUIRED_HEADERS.indexOf(header));
      return {
        range: `${quotedTab(config.tabName)}!${column}${rowNumber}`,
        majorDimension: 'ROWS',
        values: [[value]],
      };
    });
    data.push({
      range: `${quotedTab(config.tabName)}!I${rowNumber}`,
      majorDimension: 'ROWS',
      values: [[new Date().toISOString()]],
    });
    await request({
      method: 'POST',
      url: `${SHEETS_API}/${encodeURIComponent(config.spreadsheetId)}/values:batchUpdate`,
      data: { valueInputOption: 'RAW', data },
      retry: true,
    });
    cachedRows = null;
    cacheExpiresAt = 0;
    return (await readRows({ force: true })).find(
      (row) => String(row.record_id) === safeRecordId,
    );
  }

  async function writeDailyReport(dateKey, headers, rows) {
    if (!config.reportsSpreadsheetId) {
      throw new Error('GOOGLE_HR_REPORTS_SPREADSHEET_ID is missing.');
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
      throw new Error('Report date is invalid.');
    }
    if (!Array.isArray(headers) || !Array.isArray(rows) || headers.length === 0) {
      throw new Error('Report data is invalid.');
    }
    const tabTitle = `Daily_${dateKey}`;
    const metadata = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(config.reportsSpreadsheetId)}`,
      params: { fields: 'sheets.properties(sheetId,title)' },
      retry: true,
    });
    const existingSheet = (metadata.data?.sheets || []).find(
      (sheet) => sheet.properties?.title === tabTitle,
    );
    let sheetId = existingSheet?.properties?.sheetId;
    if (!existingSheet) {
      const created = await request({
        method: 'POST',
        url: `${SHEETS_API}/${encodeURIComponent(config.reportsSpreadsheetId)}:batchUpdate`,
        data: { requests: [{ addSheet: { properties: { title: tabTitle } } }] },
        retry: true,
      });
      sheetId = created.data?.replies?.[0]?.addSheet?.properties?.sheetId;
    } else {
      await request({
        method: 'POST',
        url: `${SHEETS_API}/${encodeURIComponent(config.reportsSpreadsheetId)}/values/${encodeURIComponent(`${quotedTab(tabTitle)}!A:Z`)}:clear`,
        data: {},
        retry: true,
      });
    }
    await request({
      method: 'PUT',
      url: `${SHEETS_API}/${encodeURIComponent(config.reportsSpreadsheetId)}/values/${encodeURIComponent(`${quotedTab(tabTitle)}!A1`)}`,
      params: { valueInputOption: 'RAW' },
      data: { majorDimension: 'ROWS', values: [headers, ...rows] },
      retry: true,
    });
    if (Number.isInteger(sheetId)) {
      await request({
        method: 'POST',
        url: `${SHEETS_API}/${encodeURIComponent(config.reportsSpreadsheetId)}:batchUpdate`,
        data: {
          requests: [
            {
              updateSheetProperties: {
                properties: {
                  sheetId,
                  rightToLeft: true,
                  gridProperties: { frozenRowCount: 1 },
                },
                fields: 'rightToLeft,gridProperties.frozenRowCount',
              },
            },
            {
              repeatCell: {
                range: {
                  sheetId,
                  startRowIndex: 0,
                  endRowIndex: 1,
                  startColumnIndex: 0,
                  endColumnIndex: headers.length,
                },
                cell: {
                  userEnteredFormat: {
                    backgroundColor: { red: 0.15, green: 0.82, blue: 0.88 },
                    textFormat: { bold: true, foregroundColor: { red: 0, green: 0, blue: 0 } },
                    horizontalAlignment: 'CENTER',
                  },
                },
                fields: 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)',
              },
            },
            {
              autoResizeDimensions: {
                dimensions: {
                  sheetId,
                  dimension: 'COLUMNS',
                  startIndex: 0,
                  endIndex: headers.length,
                },
              },
            },
            {
              setBasicFilter: {
                filter: {
                  range: {
                    sheetId,
                    startRowIndex: 0,
                    endRowIndex: rows.length + 1,
                    startColumnIndex: 0,
                    endColumnIndex: headers.length,
                  },
                },
              },
            },
          ],
        },
        retry: true,
      });
    }
    return {
      spreadsheetId: config.reportsSpreadsheetId,
      spreadsheetUrl: `https://docs.google.com/spreadsheets/d/${config.reportsSpreadsheetId}/edit`,
      tabTitle,
      rowCount: rows.length,
    };
  }

  async function writeWorkspaceAuditReport(headers, rows, {
    reportName = 'ZaWolf - سجل التدقيق',
    tabTitle = 'سجل التدقيق',
  } = {}) {
    if (!Array.isArray(headers) || !headers.length || !Array.isArray(rows)) {
      throw new Error('Audit report data is invalid.');
    }
    if (!String(reportName).trim() || !String(tabTitle).trim()) {
      throw new Error('Report name is invalid.');
    }
    // Service accounts do not have personal Drive storage. Prefer a workbook
    // owned by the company and shared with the service account so reports can
    // be created reliably even when the service account has zero quota. The
    // owner may place this workbook in 04_التقارير; each report receives its
    // own named tab inside it.
    let spreadsheetId = String(config.reportsSpreadsheetId || '');
    if (!spreadsheetId) {
      const rootFolderId = assertGoogleId(
        config.workspaceRootFolderId,
        'GOOGLE_WORKSPACE_ROOT_FOLDER_ID',
      );
      const reportsFolder = await ensureDriveFolder(rootFolderId, '04_التقارير');
      const found = await request({
        method: 'GET',
        url: `${DRIVE_API}/files`,
        params: {
          q: `'${driveQueryLiteral(reportsFolder.id)}' in parents and name = '${driveQueryLiteral(reportName)}' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false`,
          pageSize: 2,
          fields: 'files(id,name)',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
        },
        retry: true,
      });
      spreadsheetId = String(found.data?.files?.[0]?.id || '');
      if (!spreadsheetId) {
        const created = await request({
          method: 'POST',
          url: `${DRIVE_API}/files`,
          params: { fields: 'id,name', supportsAllDrives: true },
          data: {
            name: reportName,
            mimeType: 'application/vnd.google-apps.spreadsheet',
            parents: [reportsFolder.id],
          },
          retry: true,
        });
        spreadsheetId = String(created.data?.id || '');
      }
    }
    if (!spreadsheetId) throw new Error('Google Drive did not create the audit Sheet.');
    const metadata = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(spreadsheetId)}`,
      params: { fields: 'sheets.properties(sheetId,title)' },
      retry: true,
    });
    let target = (metadata.data?.sheets || []).find(
      (sheet) => sheet.properties?.title === tabTitle,
    );
    if (!target) {
      const created = await request({
        method: 'POST',
        url: `${SHEETS_API}/${encodeURIComponent(spreadsheetId)}:batchUpdate`,
        data: { requests: [{ addSheet: { properties: { title: tabTitle, rightToLeft: true } } }] },
        retry: true,
      });
      target = { properties: created.data?.replies?.[0]?.addSheet?.properties || {} };
    } else {
      await request({
        method: 'POST',
        url: `${SHEETS_API}/${encodeURIComponent(spreadsheetId)}/values/${encodeURIComponent(`${quotedTab(tabTitle)}!A:Z`)}:clear`,
        data: {},
        retry: true,
      });
    }
    await request({
      method: 'PUT',
      url: `${SHEETS_API}/${encodeURIComponent(spreadsheetId)}/values/${encodeURIComponent(`${quotedTab(tabTitle)}!A1`)}`,
      params: { valueInputOption: 'RAW' },
      data: { majorDimension: 'ROWS', values: [headers, ...rows] },
      retry: true,
    });
    const sheetId = target?.properties?.sheetId;
    if (Number.isInteger(sheetId)) {
      await request({
        method: 'POST',
        url: `${SHEETS_API}/${encodeURIComponent(spreadsheetId)}:batchUpdate`,
        data: { requests: [
          { updateSheetProperties: { properties: { sheetId, rightToLeft: true, gridProperties: { frozenRowCount: 1 } }, fields: 'rightToLeft,gridProperties.frozenRowCount' } },
          { repeatCell: { range: { sheetId, startRowIndex: 0, endRowIndex: 1, startColumnIndex: 0, endColumnIndex: headers.length }, cell: { userEnteredFormat: { backgroundColor: { red: 0.15, green: 0.82, blue: 0.88 }, textFormat: { bold: true, foregroundColor: { red: 0, green: 0, blue: 0 } } } }, fields: 'userEnteredFormat(backgroundColor,textFormat)' } },
          { autoResizeDimensions: { dimensions: { sheetId, dimension: 'COLUMNS', startIndex: 0, endIndex: headers.length } } },
          { setBasicFilter: { filter: { range: { sheetId, startRowIndex: 0, endRowIndex: rows.length + 1, startColumnIndex: 0, endColumnIndex: headers.length } } } },
        ] },
        retry: true,
      });
    }
    return { spreadsheetId, tabTitle, rowCount: rows.length, reportName };
  }

  async function listDriveFiles() {
    if (!config.folderId) {
      throw new Error('GOOGLE_DRIVE_TEST_FOLDER_ID is missing.');
    }
    const response = await request({
      method: 'GET',
      url: `${DRIVE_API}/files`,
      params: {
        q: `'${config.folderId}' in parents and trashed = false`,
        pageSize: 100,
        orderBy: 'name',
        fields: 'files(id,name,mimeType,modifiedTime,size)',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      },
      retry: true,
    });
    // Do not return Google web links.  Files must be opened through ZaWolf so
    // access, download and change activity stays under the company audit log.
    return (response.data?.files || []).map((file) => ({
      id: file.id,
      name: file.name,
      mimeType: file.mimeType,
      modifiedTime: file.modifiedTime,
      size: file.size,
    }));
  }

  async function listWorkspaceFolder(rawFolderId) {
    const folderId = assertGoogleId(rawFolderId, 'Drive folder id');
    const response = await request({
      method: 'GET',
      url: `${DRIVE_API}/files`,
      params: {
        q: `'${folderId}' in parents and trashed = false`,
        pageSize: 100,
        orderBy: 'folder,name',
        fields: 'files(id,name,mimeType,modifiedTime,size,webViewLink)',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      },
      retry: true,
    });
    return response.data?.files || [];
  }

  async function workspaceDriveChildMetadata(rawFolderId, rawFileId, {
    useDriveUploadOAuth = false,
  } = {}) {
    const folderId = assertGoogleId(rawFolderId, 'Drive folder id');
    const fileId = assertGoogleId(rawFileId, 'Drive file id');
    const response = await request({
      method: 'GET',
      url: `${DRIVE_API}/files/${encodeURIComponent(fileId)}`,
      params: {
        fields: 'id,name,mimeType,size,parents,trashed,modifiedTime,webViewLink',
        supportsAllDrives: true,
      },
      retry: true,
    }, { useDriveUploadOAuth });
    const metadata = response.data || {};
    if (metadata.trashed === true ||
        !Array.isArray(metadata.parents) ||
        !metadata.parents.includes(folderId)) {
      const error = new Error('Drive file is outside the assigned folder.');
      error.code = 'forbidden';
      throw error;
    }
    return metadata;
  }

  async function downloadWorkspaceDriveFile({
    folderId,
    fileId,
    useDriveUploadOAuth = false,
  }) {
    const metadata = await workspaceDriveChildMetadata(folderId, fileId, {
      useDriveUploadOAuth,
    });
    const declaredSize = Number(metadata.size || 0);
    if (declaredSize > MAX_DRIVE_DOWNLOAD_BYTES) {
      const error = new Error('Drive file is larger than the 20 MB app limit.');
      error.code = 'too_large';
      throw error;
    }
    if (metadata.mimeType === 'application/vnd.google-apps.folder') {
      throw new Error('Drive folders cannot be downloaded as files.');
    }
    let mimeType = String(metadata.mimeType || 'application/octet-stream');
    let fileName = String(metadata.name || 'download');
    let response;
    if (mimeType.startsWith('application/vnd.google-apps.')) {
      const isSpreadsheet = mimeType === 'application/vnd.google-apps.spreadsheet';
      mimeType = isSpreadsheet
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';
      fileName += isSpreadsheet ? '.xlsx' : '.pdf';
      response = await request({
        method: 'GET',
        url: `${DRIVE_API}/files/${encodeURIComponent(fileId)}/export`,
        params: { mimeType },
        responseType: 'arraybuffer',
        retry: true,
      }, { useDriveUploadOAuth });
    } else {
      response = await request({
        method: 'GET',
        url: `${DRIVE_API}/files/${encodeURIComponent(fileId)}`,
        params: { alt: 'media', supportsAllDrives: true },
        responseType: 'arraybuffer',
        retry: true,
      }, { useDriveUploadOAuth });
    }
    const contents = Buffer.from(response.data || []);
    if (contents.length > MAX_DRIVE_DOWNLOAD_BYTES) {
      const error = new Error('Drive file is larger than the 20 MB app limit.');
      error.code = 'too_large';
      throw error;
    }
    return { contents, fileName, mimeType, metadata };
  }

  async function createWorkspaceDriveFolder({
    parentFolderId,
    name,
    useDriveUploadOAuth = false,
  }) {
    const parentId = assertGoogleId(parentFolderId, 'Drive folder id');
    const folder = await ensureDriveFolder(parentId, safeFolderName(name, 'New folder'), {
      useDriveUploadOAuth,
    });
    return { id: folder.id, name: folder.name, mimeType: 'application/vnd.google-apps.folder' };
  }

  async function uploadWorkspaceDriveFile({
    parentFolderId,
    name,
    mimeType,
    contentsBase64,
    useDriveUploadOAuth = false,
  }) {
    const parentId = assertGoogleId(parentFolderId, 'Drive folder id');
    const fileName = safeFolderName(name, 'upload');
    const safeMimeType = String(mimeType || 'application/octet-stream').trim();
    if (!/^[a-z0-9.+-]+\/[a-z0-9.+-]+$/i.test(safeMimeType)) {
      throw new Error('File type is invalid.');
    }
    const encoded = String(contentsBase64 || '');
    if (!encoded || !/^[A-Za-z0-9+/=\r\n]+$/.test(encoded)) {
      throw new Error('File contents are invalid.');
    }
    const contents = Buffer.from(encoded, 'base64');
    if (!contents.length || contents.length > MAX_DRIVE_DOWNLOAD_BYTES) {
      const error = new Error('File must be between 1 byte and 20 MB.');
      error.code = 'too_large';
      throw error;
    }
    const boundary = `zawolf_${Date.now().toString(36)}`;
    const metadata = JSON.stringify({ name: fileName, mimeType: safeMimeType, parents: [parentId] });
    const prefix = Buffer.from(
      `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n` +
      `--${boundary}\r\nContent-Type: ${safeMimeType}\r\n\r\n`,
    );
    const suffix = Buffer.from(`\r\n--${boundary}--`);
    const response = await request({
      method: 'POST',
      url: `https://www.googleapis.com/upload/drive/v3/files`,
      params: { uploadType: 'multipart', fields: 'id,name,mimeType,size,modifiedTime,webViewLink,parents', supportsAllDrives: true },
      headers: { 'content-type': `multipart/related; boundary=${boundary}` },
      data: Buffer.concat([prefix, contents, suffix]),
      retry: true,
    }, { useDriveUploadOAuth });
    return response.data || {};
  }

  async function renameWorkspaceDriveFile({ parentFolderId, fileId, name }) {
    await workspaceDriveChildMetadata(parentFolderId, fileId);
    const response = await request({
      method: 'PATCH',
      url: `${DRIVE_API}/files/${encodeURIComponent(assertGoogleId(fileId, 'Drive file id'))}`,
      params: { fields: 'id,name,mimeType,size,modifiedTime,webViewLink,parents', supportsAllDrives: true },
      data: { name: safeFolderName(name, 'Untitled') },
      retry: true,
    });
    return response.data || {};
  }

  async function trashWorkspaceDriveFile({ parentFolderId, fileId }) {
    await workspaceDriveChildMetadata(parentFolderId, fileId);
    await request({
      method: 'PATCH',
      url: `${DRIVE_API}/files/${encodeURIComponent(assertGoogleId(fileId, 'Drive file id'))}`,
      params: { supportsAllDrives: true },
      data: { trashed: true },
      retry: true,
    });
  }

  async function moveWorkspaceDriveFile({ oldParentFolderId, newParentFolderId, fileId }) {
    await workspaceDriveChildMetadata(oldParentFolderId, fileId);
    const destinationId = assertGoogleId(newParentFolderId, 'Destination folder id');
    const response = await request({
      method: 'PATCH',
      url: `${DRIVE_API}/files/${encodeURIComponent(assertGoogleId(fileId, 'Drive file id'))}`,
      params: {
        addParents: destinationId,
        removeParents: assertGoogleId(oldParentFolderId, 'Drive folder id'),
        fields: 'id,name,mimeType,size,modifiedTime,webViewLink,parents',
        supportsAllDrives: true,
      },
      retry: true,
    });
    return response.data || {};
  }

  async function copyWorkspaceDriveFile({ parentFolderId, destinationFolderId, fileId, name }) {
    const metadata = await workspaceDriveChildMetadata(parentFolderId, fileId);
    if (metadata.mimeType === 'application/vnd.google-apps.folder') {
      const error = new Error('Drive folders cannot be copied from the app.');
      error.code = 'validation';
      throw error;
    }
    const destinationId = assertGoogleId(destinationFolderId, 'Destination folder id');
    const response = await request({
      method: 'POST',
      url: `${DRIVE_API}/files/${encodeURIComponent(assertGoogleId(fileId, 'Drive file id'))}/copy`,
      params: {
        fields: 'id,name,mimeType,size,modifiedTime,webViewLink,parents',
        supportsAllDrives: true,
      },
      data: {
        parents: [destinationId],
        ...(String(name || '').trim() ? { name: safeFolderName(name, metadata.name || 'Copy') } : {}),
      },
      retry: true,
    });
    return response.data || {};
  }

  async function restoreWorkspaceDriveFile({ parentFolderId, fileId }) {
    const folderId = assertGoogleId(parentFolderId, 'Drive folder id');
    const id = assertGoogleId(fileId, 'Drive file id');
    const metadataResponse = await request({
      method: 'GET',
      url: `${DRIVE_API}/files/${encodeURIComponent(id)}`,
      params: { fields: 'id,name,mimeType,parents,trashed', supportsAllDrives: true },
      retry: true,
    });
    const metadata = metadataResponse.data || {};
    if (!Array.isArray(metadata.parents) || !metadata.parents.includes(folderId)) {
      const error = new Error('Drive file is outside the assigned folder.');
      error.code = 'forbidden';
      throw error;
    }
    const response = await request({
      method: 'PATCH',
      url: `${DRIVE_API}/files/${encodeURIComponent(id)}`,
      params: { fields: 'id,name,mimeType,size,modifiedTime,webViewLink,parents', supportsAllDrives: true },
      data: { trashed: false },
      retry: true,
    });
    return response.data || {};
  }

  async function discoverWorkspaceTree(rawRootFolderId) {
    const rootFolderId = assertGoogleId(rawRootFolderId, 'Workspace root folder id');
    const output = [];
    const queue = [{ id: rootFolderId, path: '' }];
    const visited = new Set();
    const concurrency = 8;

    async function listFolder(current) {
      const children = [];
      let pageToken = '';
      do {
        const response = await request({
          method: 'GET',
          url: `${DRIVE_API}/files`,
          params: {
            q: `'${current.id}' in parents and trashed = false`,
            pageSize: 100,
            pageToken: pageToken || undefined,
            orderBy: 'folder,name',
            fields: 'nextPageToken,files(id,name,mimeType,modifiedTime,parents)',
            supportsAllDrives: true,
            includeItemsFromAllDrives: true,
          },
          retry: true,
        });
        children.push(...(response.data?.files || []));
        pageToken = String(response.data?.nextPageToken || '');
      } while (pageToken);
      return { current, children };
    }

    while (queue.length && output.length < 1500) {
      const batch = [];
      while (queue.length && batch.length < concurrency) {
        const current = queue.shift();
        if (!visited.has(current.id)) {
          visited.add(current.id);
          batch.push(current);
        }
      }
      const listings = await Promise.all(batch.map(listFolder));
      for (const { current, children } of listings) {
        for (const file of children) {
          if (output.length >= 1500) break;
          const name = String(file.name || '').trim();
          if (!file.id || !name) continue;
          // Keep the direct parent ID as well as the human-readable path.  The
          // workspace index uses this to rebuild the real Drive hierarchy; a
          // path alone cannot safely distinguish folders with the same name.
          const item = {
            ...file,
            parentExternalId: current.id,
            path: current.path ? `${current.path}/${name}` : name,
          };
          output.push(item);
          if (file.mimeType === 'application/vnd.google-apps.folder') {
            queue.push({ id: file.id, path: item.path });
          }
        }
      }
    }
    return output;
  }

  function safeFolderName(value, fallback) {
    const name = String(value || '')
      .replace(/[\\/\r\n]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    return (name || fallback).slice(0, 160);
  }

  function driveQueryLiteral(value) {
    return String(value || '').replace(/'/g, "\\'");
  }

  async function findDriveFolder(parentId, name, { useDriveUploadOAuth = false } = {}) {
    const response = await request({
      method: 'GET',
      url: `${DRIVE_API}/files`,
      params: {
        q: `'${driveQueryLiteral(parentId)}' in parents and name = '${driveQueryLiteral(name)}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false`,
        pageSize: 2,
        orderBy: 'createdTime',
        fields: 'files(id,name)',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      },
      retry: true,
    }, { useDriveUploadOAuth });
    return (response.data?.files || [])[0] || null;
  }

  async function ensureDriveFolder(parentId, rawName, { useDriveUploadOAuth = false } = {}) {
    const name = safeFolderName(rawName, 'Untitled');
    const existing = await findDriveFolder(parentId, name, { useDriveUploadOAuth });
    if (existing?.id) return { id: String(existing.id), created: false, name };
    const response = await request({
      method: 'POST',
      url: `${DRIVE_API}/files`,
      params: {
        fields: 'id,name',
        supportsAllDrives: true,
      },
      data: {
        name,
        mimeType: 'application/vnd.google-apps.folder',
        parents: [parentId],
      },
      retry: true,
    }, { useDriveUploadOAuth });
    if (!response.data?.id) throw new Error(`Google Drive did not create folder: ${name}`);
    return { id: String(response.data.id), created: true, name };
  }

  async function moveDriveFolder(folderId, oldParentId, newParentId) {
    if (!folderId || oldParentId === newParentId) return;
    await request({
      method: 'PATCH',
      url: `${DRIVE_API}/files/${encodeURIComponent(folderId)}`,
      params: {
        addParents: newParentId,
        removeParents: oldParentId,
        fields: 'id,parents',
        supportsAllDrives: true,
      },
      data: {},
      retry: true,
    });
  }

  // Creates a predictable workspace without moving or modifying existing
  // company files. Re-running it is idempotent: folders with the same parent
  // and name are reused, and only missing department/employee folders appear.
  async function ensureCompanyWorkspaceStructure({ departments = [], employees = [] } = {}) {
    const rootFolderId = assertGoogleId(
      config.workspaceRootFolderId,
      'GOOGLE_WORKSPACE_ROOT_FOLDER_ID',
    );
    const folders = [
      ['administration', '00_الإدارة_العامة'],
      ['humanResources', '01_الموارد_البشرية'],
      ['departments', '02_الأقسام'],
      ['employees', '03_ملفات_الموظفين'],
      ['reports', '04_التقارير'],
      ['shared', '05_ملفات_مشتركة'],
      ['archive', '99_الأرشيف'],
    ];
    const ids = {};
    let created = 0;
    for (const [key, name] of folders) {
      const folder = await ensureDriveFolder(rootFolderId, name);
      ids[key] = folder.id;
      if (folder.created) created += 1;
    }

    const uniqueDepartments = [...new Set(
      (Array.isArray(departments) ? departments : [])
        .map((department) => safeFolderName(department, 'غير_محدد')),
    )].sort((a, b) => a.localeCompare(b, 'ar'));
    let departmentFolders = 0;
    const employeeDepartmentIds = new Map();
    for (const department of uniqueDepartments) {
      const folder = await ensureDriveFolder(ids.employees, department);
      employeeDepartmentIds.set(department, folder.id);
      if (folder.created) {
        created += 1;
        departmentFolders += 1;
      }
    }

    let employeeFolders = 0;
    const seenEmployees = new Set();
    for (const employee of Array.isArray(employees) ? employees : []) {
      const employeeId = String(employee?.employeeId || '').trim().toUpperCase();
      if (!employeeId || seenEmployees.has(employeeId)) continue;
      seenEmployees.add(employeeId);
      const displayName = safeFolderName(employee?.displayName, 'موظف');
      const department = safeFolderName(employee?.department, 'غير_محدد');
      let departmentFolderId = employeeDepartmentIds.get(department);
      if (!departmentFolderId) {
        const departmentFolder = await ensureDriveFolder(ids.employees, department);
        departmentFolderId = departmentFolder.id;
        employeeDepartmentIds.set(department, departmentFolderId);
        if (departmentFolder.created) {
          created += 1;
          departmentFolders += 1;
        }
      }
      const folderName = `${employeeId} - ${displayName}`;
      // Migrate the old flat layout without copying its contents or creating a
      // second employee folder.
      const targetFolder = await findDriveFolder(departmentFolderId, folderName);
      const oldFolder = targetFolder?.id
        ? null
        : await findDriveFolder(ids.employees, folderName);
      if (!targetFolder?.id && oldFolder?.id) {
        await moveDriveFolder(oldFolder.id, ids.employees, departmentFolderId);
      }
      const folder = targetFolder?.id || oldFolder?.id
        ? { id: String(targetFolder?.id || oldFolder.id), created: false, name: folderName }
        : await ensureDriveFolder(departmentFolderId, folderName);
      if (folder.created) {
        created += 1;
        employeeFolders += 1;
      }
    }
    return {
      rootFolderId,
      created,
      departmentFolders,
      employeeFolders,
      folders: ids,
    };
  }

  async function downloadDriveFile(rawFileId) {
    if (!config.folderId) {
      throw new Error('GOOGLE_DRIVE_TEST_FOLDER_ID is missing.');
    }
    const fileId = String(rawFileId || '').trim();
    if (!/^[A-Za-z0-9_-]{10,}$/.test(fileId)) {
      throw new Error('Drive file id is invalid.');
    }
    const metadataResponse = await request({
      method: 'GET',
      url: `${DRIVE_API}/files/${encodeURIComponent(fileId)}`,
      params: {
        fields: 'id,name,mimeType,size,parents,trashed',
        supportsAllDrives: true,
      },
      retry: true,
    });
    const metadata = metadataResponse.data || {};
    if (metadata.trashed === true ||
        !Array.isArray(metadata.parents) ||
        !metadata.parents.includes(config.folderId)) {
      const error = new Error('Drive file is outside the configured folder.');
      error.code = 'forbidden';
      throw error;
    }
    const declaredSize = Number(metadata.size || 0);
    if (declaredSize > MAX_DRIVE_DOWNLOAD_BYTES) {
      const error = new Error('Drive file is larger than the 20 MB app limit.');
      error.code = 'too_large';
      throw error;
    }
    if (metadata.mimeType === 'application/vnd.google-apps.folder') {
      throw new Error('Drive folders cannot be downloaded as files.');
    }

    let mimeType = String(metadata.mimeType || 'application/octet-stream');
    let fileName = String(metadata.name || 'download');
    let response;
    if (mimeType.startsWith('application/vnd.google-apps.')) {
      const isSpreadsheet = mimeType === 'application/vnd.google-apps.spreadsheet';
      mimeType = isSpreadsheet
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';
      fileName += isSpreadsheet ? '.xlsx' : '.pdf';
      response = await request({
        method: 'GET',
        url: `${DRIVE_API}/files/${encodeURIComponent(fileId)}/export`,
        params: { mimeType },
        responseType: 'arraybuffer',
        retry: true,
      });
    } else {
      response = await request({
        method: 'GET',
        url: `${DRIVE_API}/files/${encodeURIComponent(fileId)}`,
        params: { alt: 'media', supportsAllDrives: true },
        responseType: 'arraybuffer',
        retry: true,
      });
    }
    const contents = Buffer.from(response.data || []);
    if (contents.length > MAX_DRIVE_DOWNLOAD_BYTES) {
      const error = new Error('Drive file is larger than the 20 MB app limit.');
      error.code = 'too_large';
      throw error;
    }
    return { contents, fileName, mimeType };
  }

  async function createDriveTestFile(rawName, rawContents) {
    if (!config.folderId) {
      throw new Error('GOOGLE_DRIVE_TEST_FOLDER_ID is missing.');
    }
    const name = String(rawName || 'ZaWolf HR Drive API Test.txt').trim();
    if (!/^[^\\/\\\r\\\n]{1,100}$/.test(name) || name.startsWith('.')) {
      throw new Error('Drive test filename is invalid.');
    }
    const contents = String(rawContents || '').trim();
    if (contents.length > 5000) throw new Error('Drive test contents are too long.');
    const response = await request({
      method: 'POST',
      url: `${DRIVE_API}/files`,
      params: {
        fields: 'id,name,mimeType,modifiedTime,size,webViewLink,parents',
        supportsAllDrives: true,
      },
      headers: {
        'content-type': 'application/json; charset=utf-8',
      },
      data: {
        name,
        mimeType: 'text/plain',
        parents: [config.folderId],
        description: contents || 'ZaWolf HR Drive API test',
      },
      retry: true,
    });
    return response.data;
  }

  function assertGoogleId(value, label = 'Google resource id') {
    const id = String(value || '').trim();
    if (!/^[A-Za-z0-9_-]{10,}$/.test(id)) {
      throw new Error(`${label} is invalid.`);
    }
    return id;
  }

  // These methods are used by the company workspace centre.  Unlike the
  // test-sheet methods above, the spreadsheet/folder id is supplied by a
  // Firestore resource record after the server has checked the caller's
  // workspace grant.  IDs never travel back to the Flutter client.
  async function readWorkspaceSheet({
    spreadsheetId,
    tabName = '',
    headerRow = 1,
    startRow,
    startColumn = 1,
    rowCount,
    columnCount,
  }) {
    const id = assertGoogleId(spreadsheetId, 'Spreadsheet id');
    const metadata = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(id)}`,
      params: { fields: 'sheets.properties(title,index,sheetId,gridProperties(rowCount,columnCount))' },
      retry: true,
    });
    const tabs = (metadata.data?.sheets || [])
      .map((sheet) => String(sheet.properties?.title || ''))
      .filter(Boolean);
    const selectedTab = String(tabName || '').trim() || tabs[0];
    if (!selectedTab || !tabs.includes(selectedTab)) {
      throw new Error('The configured Sheet tab was not found.');
    }
    const selectedProperties = (metadata.data?.sheets || []).find(
      (sheet) => String(sheet.properties?.title || '') === selectedTab,
    )?.properties || {};
    const safeHeaderRow = Math.max(1, Math.min(Number(headerRow) || 1, 50));
    const safeStartRow = Math.max(safeHeaderRow + 1, Math.min(Number(startRow) || safeHeaderRow + 1, 100000));
    const safeStartColumn = Math.max(1, Math.min(Number(startColumn) || 1, 702));
    // The legacy editor retains a 500-row default while the V2 caller opts
    // into a smaller viewport. Both paths are now bounded provider requests.
    const safeRowCount = Math.max(1, Math.min(Number(rowCount) || 500, 500));
    const headerRange = `${quotedTab(selectedTab)}!A${safeHeaderRow}:ZZ${safeHeaderRow}`;
    const headerResponse = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(id)}/values/${encodeURIComponent(headerRange)}`,
      params: { majorDimension: 'ROWS', valueRenderOption: 'FORMATTED_VALUE' },
      retry: true,
    });
    const suppliedHeaders = (headerResponse.data?.values?.[0] || []).map((value, index) => {
      const valueText = String(value || '').trim();
      return valueText || `column_${index + 1}`;
    });
    // Old callers do not pass a viewport width.  Do not accidentally render
    // every possible Google Sheet column for them; use the populated header
    // width. V2 always passes an explicit, bounded column count.
    const requestedColumnCount = Number(columnCount);
    const safeColumnCount = Math.max(1, Math.min(
      Number.isFinite(requestedColumnCount) && requestedColumnCount > 0
        ? requestedColumnCount
        : Math.max(1, suppliedHeaders.length),
      702,
    ));
    const knownColumnCount = Number(selectedProperties.gridProperties?.columnCount || 1);
    const lastColumn = Math.max(safeStartColumn, Math.min(
      safeStartColumn + safeColumnCount - 1, knownColumnCount || 1, 702,
    ));
    const headers = Array.from({ length: Math.max(suppliedHeaders.length, lastColumn) }, (_, index) =>
      suppliedHeaders[index] || `column_${index + 1}`,
    );
    const lastRow = Math.min(safeStartRow + safeRowCount - 1, 100000);
    const headerGridRange = `${quotedTab(selectedTab)}!A${safeHeaderRow}:${columnName(lastColumn - 1)}${safeHeaderRow}`;
    const gridRange = `${quotedTab(selectedTab)}!${columnName(safeStartColumn - 1)}${safeStartRow}:${columnName(lastColumn - 1)}${lastRow}`;
    const readGrid = async (range) => request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(id)}`,
      params: {
        ranges: range,
        includeGridData: true,
        fields: 'sheets(properties(title,gridProperties(rowCount,columnCount)),merges,data(startRow,startColumn,rowData(values(formattedValue,effectiveValue,userEnteredValue,note,hyperlink,dataValidation,userEnteredFormat(backgroundColor,textFormat,horizontalAlignment,verticalAlignment,wrapStrategy,numberFormat),effectiveFormat(backgroundColor,textFormat,horizontalAlignment,verticalAlignment,wrapStrategy,numberFormat)))))',
      },
      retry: true,
    });
    const [headerGrid, grid] = await Promise.all([readGrid(headerGridRange), readGrid(gridRange)]);
    const headerGridSheet = (headerGrid.data?.sheets || []).find(
      (item) => String(item.properties?.title || '') === selectedTab,
    );
    const gridSheet = (grid.data?.sheets || []).find(
      (item) => String(item.properties?.title || '') === selectedTab,
    );
    const headerData = headerGridSheet?.data?.[0]?.rowData?.[0]?.values || [];
    const rowData = gridSheet?.data?.[0]?.rowData || [];
    const colorHex = (color) => {
      if (!color || typeof color !== 'object') return null;
      const channel = (value) => Math.max(0, Math.min(255, Math.round(Number(value || 0) * 255)))
        .toString(16).padStart(2, '0');
      return `#${channel(color.red)}${channel(color.green)}${channel(color.blue)}`.toUpperCase();
    };
    const rawValue = (cell) => {
      const value = cell?.userEnteredValue || {};
      if (value.formulaValue != null) return String(value.formulaValue);
      if (value.stringValue != null) return String(value.stringValue);
      if (value.numberValue != null) return value.numberValue;
      if (value.boolValue != null) return value.boolValue;
      return cell?.formattedValue ?? '';
    };
    const cellMetadata = (cell) => {
      const entered = cell?.userEnteredFormat || {};
      const effective = cell?.effectiveFormat || {};
      const validation = cell?.dataValidation || {};
      const condition = validation.condition || {};
      return {
        rawValue: rawValue(cell),
        formattedValue: cell?.formattedValue ?? '',
        note: String(cell?.note || ''),
        hyperlink: String(cell?.hyperlink || ''),
        // Keep the ZaWolf dark canvas for cells that use Google's implicit
        // white/black defaults. Explicit user formatting is still preserved.
        backgroundColor: colorHex(entered.backgroundColor),
        textColor: colorHex(entered.textFormat?.foregroundColor),
        bold: entered.textFormat?.bold === true,
        italic: entered.textFormat?.italic === true,
        fontSize: Number(entered.textFormat?.fontSize || effective.textFormat?.fontSize || 0) || null,
        horizontalAlignment: String(entered.horizontalAlignment || effective.horizontalAlignment || ''),
        verticalAlignment: String(entered.verticalAlignment || effective.verticalAlignment || ''),
        wrapStrategy: String(entered.wrapStrategy || effective.wrapStrategy || ''),
        numberFormat: entered.numberFormat || effective.numberFormat || null,
        validationType: String(condition.type || ''),
        validationValues: (condition.values || []).map((item) => String(item.userEnteredValue || '')),
        validationStrict: validation.strict === true,
      };
    };
    const visibleHeaders = headers.slice(safeStartColumn - 1, lastColumn);
    const headerCells = visibleHeaders.map((_, column) => cellMetadata(headerData[safeStartColumn - 1 + column]));
    const rows = rowData.map((dataRow, index) => {
      const cells = dataRow?.values || [];
      return {
        rowNumber: safeStartRow + index,
        values: Object.fromEntries(visibleHeaders.map((header, column) => [header, cells[column]?.formattedValue ?? ''])),
        cells: Object.fromEntries(visibleHeaders.map((header, column) => [header, cellMetadata(cells[column])])),
      };
    });
    return {
      tabName: selectedTab,
      headers: visibleHeaders,
      headerCells,
      rows,
      tabs,
      merges: gridSheet?.merges || [],
      viewport: {
        startRow: safeStartRow,
        startColumn: safeStartColumn,
        rowCount: safeRowCount,
        columnCount: visibleHeaders.length,
        totalRows: Number(gridSheet?.properties?.gridProperties?.rowCount || selectedProperties.gridProperties?.rowCount || 0),
        totalColumns: Number(gridSheet?.properties?.gridProperties?.columnCount || knownColumnCount || 0),
      },
      // Sheets does not expose a per-range revision token. Bind the client
      // version to the returned viewport so a stale edit is detected before
      // the next mutation, without leaking provider revision metadata.
      version: crypto.createHash('sha256').update(JSON.stringify({
        tab: selectedTab,
        startRow: safeStartRow,
        startColumn: safeStartColumn,
        headerData,
        rowData,
        merges: gridSheet?.merges || [],
      })).digest('hex'),
    };
  }

  async function updateWorkspaceSheetCells({ spreadsheetId, tabName, cells }) {
    const id = assertGoogleId(spreadsheetId, 'Spreadsheet id');
    if (!Array.isArray(cells) || !cells.length || cells.length > 500) {
      throw new Error('Sheet cell update is invalid.');
    }
    const data = cells.map((cell) => {
      const row = Number(cell?.row);
      const column = Number(cell?.column);
      const value = String(cell?.value ?? '');
      if (!Number.isInteger(row) || row < 1 || row > 100000 ||
          !Number.isInteger(column) || column < 1 || column > 702 || value.length > 10000) {
        throw new Error('Sheet cell update is invalid.');
      }
      return {
        range: `${quotedTab(tabName)}!${columnName(column - 1)}${row}`,
        majorDimension: 'ROWS',
        values: [[value]],
      };
    });
    await request({
      method: 'POST',
      url: `${SHEETS_API}/${encodeURIComponent(id)}/values:batchUpdate`,
      data: { valueInputOption: 'USER_ENTERED', data },
      retry: true,
    });
  }

  async function workspaceSheetProperties(spreadsheetId, tabName) {
    const id = assertGoogleId(spreadsheetId, 'Spreadsheet id');
    const response = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(id)}`,
      params: { fields: 'sheets.properties(title,sheetId,gridProperties(rowCount,columnCount))' },
      retry: true,
    });
    const sheet = (response.data?.sheets || []).find(
      (item) => String(item.properties?.title || '') === String(tabName || ''),
    );
    if (!sheet?.properties || !Number.isInteger(sheet.properties.sheetId)) {
      throw new Error('The configured Sheet tab was not found.');
    }
    return { id, properties: sheet.properties };
  }

  function normalizeSheetColor(value) {
    const color = String(value || '').trim();
    if (!/^#[0-9A-Fa-f]{6}$/.test(color)) throw new Error('Sheet color is invalid.');
    return {
      red: parseInt(color.slice(1, 3), 16) / 255,
      green: parseInt(color.slice(3, 5), 16) / 255,
      blue: parseInt(color.slice(5, 7), 16) / 255,
    };
  }

  async function formatWorkspaceSheetRange({ spreadsheetId, tabName, startRow, endRow, startColumn, endColumn, backgroundColor, textColor, bold, italic, horizontalAlignment, wrapStrategy, dropdownValues, checkbox, clearValidation, clearFormatting }) {
    const { id, properties } = await workspaceSheetProperties(spreadsheetId, tabName);
    const bounds = [startRow, endRow, startColumn, endColumn].map(Number);
    if (!bounds.every(Number.isInteger) || bounds[0] < 1 || bounds[1] < bounds[0] || bounds[2] < 1 || bounds[3] < bounds[2] || bounds[1] > 100000 || bounds[3] > 702) {
      throw new Error('Sheet range is invalid.');
    }
    const format = {};
    const fields = [];
    if (backgroundColor) {
      format.backgroundColor = normalizeSheetColor(backgroundColor);
      fields.push('userEnteredFormat.backgroundColor');
    }
    const textFormat = {};
    if (textColor) textFormat.foregroundColor = normalizeSheetColor(textColor);
    if (typeof bold === 'boolean') textFormat.bold = bold;
    if (typeof italic === 'boolean') textFormat.italic = italic;
    if (Object.keys(textFormat).length) {
      format.textFormat = textFormat;
      if (textColor) fields.push('userEnteredFormat.textFormat.foregroundColor');
      if (typeof bold === 'boolean') fields.push('userEnteredFormat.textFormat.bold');
      if (typeof italic === 'boolean') fields.push('userEnteredFormat.textFormat.italic');
    }
    if (['LEFT', 'CENTER', 'RIGHT'].includes(horizontalAlignment)) {
      format.horizontalAlignment = horizontalAlignment;
      fields.push('userEnteredFormat.horizontalAlignment');
    }
    if (['WRAP', 'CLIP', 'OVERFLOW_CELL'].includes(wrapStrategy)) {
      format.wrapStrategy = wrapStrategy;
      fields.push('userEnteredFormat.wrapStrategy');
    }
    const range = {
      sheetId: properties.sheetId,
      startRowIndex: bounds[0] - 1,
      endRowIndex: bounds[1],
      startColumnIndex: bounds[2] - 1,
      endColumnIndex: bounds[3],
    };
    const requests = [];
    if (clearFormatting === true) {
      requests.push({ repeatCell: { range, cell: { userEnteredFormat: {} }, fields: 'userEnteredFormat' } });
    } else if (fields.length) {
      requests.push({ repeatCell: { range, cell: { userEnteredFormat: format }, fields: fields.join(',') } });
    }
    if (clearValidation === true) {
      requests.push({ setDataValidation: { range, rule: null } });
    } else if (checkbox === true) {
      requests.push({ setDataValidation: { range, rule: { condition: { type: 'BOOLEAN' }, strict: true, showCustomUi: true } } });
    } else if (Array.isArray(dropdownValues) && dropdownValues.length) {
      const labels = dropdownValues.map((value) => String(value || '').trim()).filter(Boolean).slice(0, 100);
      if (!labels.length) throw new Error('Dropdown labels are empty.');
      requests.push({ setDataValidation: { range, rule: { condition: { type: 'ONE_OF_LIST', values: labels.map((value) => ({ userEnteredValue: value })) }, strict: true, showCustomUi: true } } });
    }
    if (!requests.length) throw new Error('Choose at least one format option.');
    await request({
      method: 'POST',
      url: `${SHEETS_API}/${encodeURIComponent(id)}:batchUpdate`,
      data: {
        requests,
      },
      retry: true,
    });
  }

  async function changeWorkspaceSheetStructure({ spreadsheetId, tabName, operation, index, count = 1, headerRow = 1, headerValue = '' }) {
    const { id, properties } = await workspaceSheetProperties(spreadsheetId, tabName);
    const safeIndex = Number(index);
    const safeCount = Math.max(1, Math.min(Number(count) || 1, 100));
    if (!Number.isInteger(safeIndex) || safeIndex < 1 || safeIndex > 100000) {
      throw new Error('Sheet position is invalid.');
    }
    let requestBody;
    if (operation === 'insert_row' || operation === 'delete_row') {
      requestBody = operation === 'insert_row'
        ? { insertDimension: { range: { sheetId: properties.sheetId, dimension: 'ROWS', startIndex: safeIndex - 1, endIndex: safeIndex - 1 + safeCount }, inheritFromBefore: safeIndex > 1 } }
        : { deleteDimension: { range: { sheetId: properties.sheetId, dimension: 'ROWS', startIndex: safeIndex - 1, endIndex: safeIndex - 1 + safeCount } } };
    } else if (operation === 'insert_column' || operation === 'delete_column') {
      if (safeIndex > 702) throw new Error('Sheet column position is invalid.');
      requestBody = operation === 'insert_column'
        ? { insertDimension: { range: { sheetId: properties.sheetId, dimension: 'COLUMNS', startIndex: safeIndex - 1, endIndex: safeIndex - 1 + safeCount }, inheritFromBefore: safeIndex > 1 } }
        : { deleteDimension: { range: { sheetId: properties.sheetId, dimension: 'COLUMNS', startIndex: safeIndex - 1, endIndex: safeIndex - 1 + safeCount } } };
    } else {
      throw new Error('Sheet structure operation is invalid.');
    }
    await request({
      method: 'POST',
      url: `${SHEETS_API}/${encodeURIComponent(id)}:batchUpdate`,
      data: {
        requests: [
          requestBody,
          ...(operation === 'insert_column' && String(headerValue || '').trim()
            ? [{ updateCells: {
              range: {
                sheetId: properties.sheetId,
                startRowIndex: Math.max(0, Math.min(Number(headerRow) || 1, 50) - 1),
                endRowIndex: Math.max(1, Math.min(Number(headerRow) || 1, 50)),
                startColumnIndex: safeIndex - 1,
                endColumnIndex: safeIndex,
              },
              rows: [{ values: [{ userEnteredValue: { stringValue: String(headerValue).trim().slice(0, 200) } }] }],
              fields: 'userEnteredValue',
            } }] : []),
        ],
      },
      retry: true,
    });
  }

  async function configureWorkspaceSheetFilter({ spreadsheetId, tabName, operation, startRow, endRow, startColumn, endColumn, sortColumn, descending = false }) {
    const { id, properties } = await workspaceSheetProperties(spreadsheetId, tabName);
    if (operation === 'clear_filter') {
      await request({
        method: 'POST', url: `${SHEETS_API}/${encodeURIComponent(id)}:batchUpdate`,
        data: { requests: [{ clearBasicFilter: { sheetId: properties.sheetId } }] }, retry: true,
      });
      return;
    }
    const values = [startRow, endRow, startColumn, endColumn].map(Number);
    if (!values.every(Number.isInteger) || values[0] < 1 || values[1] < values[0] ||
        values[2] < 1 || values[3] < values[2] || values[1] > 100000 || values[3] > 702) {
      throw new Error('Sheet filter range is invalid.');
    }
    const range = {
      sheetId: properties.sheetId,
      startRowIndex: values[0] - 1,
      endRowIndex: values[1],
      startColumnIndex: values[2] - 1,
      endColumnIndex: values[3],
    };
    const requestBody = operation === 'set_filter'
      ? { setBasicFilter: { filter: { range } } }
      : operation === 'sort_range'
        ? { sortRange: {
          range,
          sortSpecs: [{ dimensionIndex: Math.max(0, Math.min(Number(sortColumn) || values[2], 702) - 1), sortOrder: descending ? 'DESCENDING' : 'ASCENDING' }],
        } }
        : null;
    if (!requestBody) throw new Error('Sheet filter operation is invalid.');
    await request({
      method: 'POST', url: `${SHEETS_API}/${encodeURIComponent(id)}:batchUpdate`,
      data: { requests: [requestBody] }, retry: true,
    });
  }

  async function changeWorkspaceSheetTab({ spreadsheetId, operation, tabName = '', newName = '' }) {
    const id = assertGoogleId(spreadsheetId, 'Spreadsheet id');
    const metadata = await request({
      method: 'GET',
      url: `${SHEETS_API}/${encodeURIComponent(id)}`,
      params: { fields: 'sheets.properties(title,sheetId,index)' },
      retry: true,
    });
    const sheets = metadata.data?.sheets || [];
    const cleanName = (value) => {
      const name = String(value || '').trim();
      if (!name || name.length > 100 || /[\\/:?*\[\]]/.test(name)) {
        throw new Error('Sheet tab name is invalid.');
      }
      return name;
    };
    let requestBody;
    let selectedTab;
    if (operation === 'add') {
      selectedTab = cleanName(newName);
      if (sheets.some((sheet) => String(sheet.properties?.title || '').toLowerCase() === selectedTab.toLowerCase())) {
        throw new Error('A Sheet tab with this name already exists.');
      }
      requestBody = {
        addSheet: {
          properties: {
            title: selectedTab,
            gridProperties: { rowCount: 1000, columnCount: 26 },
          },
        },
      };
    } else {
      const current = sheets.find(
        (sheet) => String(sheet.properties?.title || '') === String(tabName || '').trim(),
      );
      if (!current?.properties || !Number.isInteger(current.properties.sheetId)) {
        throw new Error('The selected Sheet tab was not found.');
      }
      if (operation === 'rename') {
        selectedTab = cleanName(newName);
        if (sheets.some((sheet) => sheet !== current &&
            String(sheet.properties?.title || '').toLowerCase() === selectedTab.toLowerCase())) {
          throw new Error('A Sheet tab with this name already exists.');
        }
        requestBody = {
          updateSheetProperties: {
            properties: { sheetId: current.properties.sheetId, title: selectedTab },
            fields: 'title',
          },
        };
      } else if (operation === 'delete') {
        if (sheets.length <= 1) throw new Error('The last Sheet tab cannot be deleted.');
        requestBody = { deleteSheet: { sheetId: current.properties.sheetId } };
        selectedTab = String(
          sheets.find((sheet) => sheet !== current)?.properties?.title || '',
        );
      } else {
        throw new Error('Sheet tab operation is invalid.');
      }
    }
    const response = await request({
      method: 'POST',
      url: `${SHEETS_API}/${encodeURIComponent(id)}:batchUpdate`,
      data: { requests: [requestBody] },
      retry: true,
    });
    if (operation === 'add') {
      const createdSheetId = response.data?.replies?.[0]?.addSheet?.properties?.sheetId;
      if (Number.isInteger(createdSheetId)) {
        await request({
          method: 'POST',
          url: `${SHEETS_API}/${encodeURIComponent(id)}:batchUpdate`,
          data: {
            requests: [{
              updateCells: {
                start: { sheetId: createdSheetId, rowIndex: 0, columnIndex: 0 },
                rows: [{ values: [{ userEnteredValue: { stringValue: 'Column 1' } }] }],
                fields: 'userEnteredValue',
              },
            }],
          },
          retry: true,
        });
      }
    }
    return { tabName: selectedTab };
  }

  async function updateWorkspaceSheetRow({ spreadsheetId, tabName, rowNumber, headers, updates, editableHeaders }) {
    const id = assertGoogleId(spreadsheetId, 'Spreadsheet id');
    const safeRow = Number(rowNumber);
    if (!Number.isInteger(safeRow) || safeRow < 2 || safeRow > 100000) {
      throw new Error('Sheet row number is invalid.');
    }
    if (!Array.isArray(headers) || !headers.length || !updates || typeof updates !== 'object') {
      throw new Error('Sheet update is invalid.');
    }
    const allowed = new Set((editableHeaders || []).map((value) => String(value).trim()));
    const data = [];
    for (const [header, rawValue] of Object.entries(updates)) {
      if (!allowed.has(header)) throw new Error(`Field is not editable: ${header}`);
      const column = headers.indexOf(header);
      if (column < 0) throw new Error(`Field was not found in the Sheet: ${header}`);
      const value = String(rawValue ?? '').trim();
      if (value.length > 2000) {
        throw new Error(`Invalid value for ${header}`);
      }
      data.push({
        range: `${quotedTab(tabName)}!${columnName(column)}${safeRow}`,
        majorDimension: 'ROWS',
        values: [[value]],
      });
    }
    if (!data.length) throw new Error('At least one field must be updated.');
    await request({
      method: 'POST',
      url: `${SHEETS_API}/${encodeURIComponent(id)}/values:batchUpdate`,
      data: { valueInputOption: 'USER_ENTERED', data },
      retry: true,
    });
  }

  return {
    config,
    readRows,
    updateRow,
    writeDailyReport,
    writeWorkspaceAuditReport,
    listDriveFiles,
    listWorkspaceFolder,
    downloadWorkspaceDriveFile,
    createWorkspaceDriveFolder,
    uploadWorkspaceDriveFile,
    renameWorkspaceDriveFile,
    trashWorkspaceDriveFile,
    moveWorkspaceDriveFile,
    copyWorkspaceDriveFile,
    restoreWorkspaceDriveFile,
    discoverWorkspaceTree,
    ensureCompanyWorkspaceStructure,
    downloadDriveFile,
    createDriveTestFile,
    readWorkspaceSheet,
    updateWorkspaceSheetCells,
    updateWorkspaceSheetRow,
    formatWorkspaceSheetRange,
    changeWorkspaceSheetStructure,
    configureWorkspaceSheetFilter,
    changeWorkspaceSheetTab,
  };
}

module.exports = {
  ALLOWED_STATUSES,
  DRIVE_SCOPE,
  MAX_DRIVE_DOWNLOAD_BYTES,
  REQUIRED_HEADERS,
  columnName,
  createGoogleSheetsIntegration,
  mapRows,
  parseServiceAccount,
  validateUpdate,
};
