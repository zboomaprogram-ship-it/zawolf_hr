const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  columnName,
  createGoogleSheetsIntegration,
  mapRows,
  parseServiceAccount,
  validateUpdate,
} = require('../google-sheets-integration');

const headers = [
  'record_id', 'employee_id', 'employee_name', 'department', 'task_name',
  'status', 'amount', 'notes', 'updated_at',
];

test('maps the test sheet by header and does not expose row coordinates', () => {
  const rows = mapRows([
    headers,
    ['TEST-001', 'EMP-TEST-001', 'أحمد تجريبي', 'Sales', 'إعداد عرض', 'pending', 1500, '', '2026-08-11'],
  ]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].record_id, 'TEST-001');
  assert.equal(rows[0]._rowNumber, 2);
  assert.equal(JSON.stringify(rows[0]).includes('_rowNumber'), false);
});

test('rejects missing headers and non-editable identity fields', () => {
  assert.throws(() => mapRows([['record_id']]), /missing required headers/);
  assert.throws(
    () => validateUpdate({ employee_id: 'EMP-OTHER' }),
    /not editable/,
  );
});

test('validates status, amount, and formula-like input', () => {
  assert.deepEqual(
    validateUpdate({ status: 'completed', amount: '2200', notes: 'تم التنفيذ' }),
    { status: 'completed', amount: 2200, notes: 'تم التنفيذ' },
  );
  assert.throws(() => validateUpdate({ status: 'approved' }), /status must be/);
  assert.throws(() => validateUpdate({ notes: '=IMPORTDATA("x")' }), /formula/);
  assert.throws(() => validateUpdate({ amount: -1 }), /non-negative/);
});

test('updates only the selected cells and refreshes the row', async () => {
  const requests = [];
  let currentStatus = 'pending';
  const authClient = {
    async request(options) {
      requests.push(options);
      if (options.method === 'POST') {
        const statusUpdate = options.data.data.find((item) => item.range.endsWith('F2'));
        if (statusUpdate) currentStatus = statusUpdate.values[0][0];
        return { data: { totalUpdatedCells: options.data.data.length } };
      }
      return {
        data: {
          values: [
            headers,
            ['TEST-001', 'EMP-TEST-001', 'أحمد', 'Sales', 'إعداد عرض', currentStatus, 1500, '', '2026-08-11'],
          ],
        },
      };
    },
  };
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_SHEETS_TEST_TAB: 'Employee_Test_Data',
    },
    authClient,
  });

  const updated = await sheets.updateRow('TEST-001', { status: 'completed' });
  assert.equal(updated.status, 'completed');
  assert.equal(requests.filter((item) => item.method === 'GET').length, 2);
  const write = requests.find((item) => item.method === 'POST');
  assert.deepEqual(
    write.data.data.map((item) => item.range),
    ["'Employee_Test_Data'!F2", "'Employee_Test_Data'!I2"],
  );
  assert.equal(write.data.valueInputOption, 'RAW');
});

test('normalizes escaped private-key newlines', () => {
  const parsed = parseServiceAccount(JSON.stringify({
    project_id: 'test-project',
    client_email: 'sheets@example.iam.gserviceaccount.com',
    private_key: 'line1\\nline2',
  }));
  assert.equal(parsed.private_key, 'line1\nline2');
});

test('converts zero-based indexes to spreadsheet columns', () => {
  assert.equal(columnName(0), 'A');
  assert.equal(columnName(25), 'Z');
  assert.equal(columnName(26), 'AA');
});

test('lists Drive files only inside the configured test folder', async () => {
  const requests = [];
  const authClient = {
    async request(options) {
      requests.push(options);
      return { data: { files: [{ id: 'file-1', name: 'test.txt', mimeType: 'text/plain' }] } };
    },
  };
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_DRIVE_TEST_FOLDER_ID: '1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_',
    },
    authClient,
  });
  const files = await sheets.listDriveFiles();
  assert.equal(files[0].id, 'file-1');
  assert.match(requests[0].params.q, /1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_/);
  assert.match(requests[0].params.q, /trashed = false/);
});

test('downloads only files inside the configured Drive folder', async () => {
  const requests = [];
  const authClient = {
    async request(options) {
      requests.push(options);
      if (options.params?.fields?.includes('parents')) {
        return {
          data: {
            id: 'valid-file-123',
            name: 'policy.pdf',
            mimeType: 'application/pdf',
            size: '4',
            parents: ['1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_'],
            trashed: false,
          },
        };
      }
      return { data: Buffer.from('test') };
    },
  };
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_DRIVE_TEST_FOLDER_ID: '1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_',
    },
    authClient,
  });
  const file = await sheets.downloadDriveFile('valid-file-123');
  assert.equal(file.fileName, 'policy.pdf');
  assert.equal(file.mimeType, 'application/pdf');
  assert.equal(file.contents.toString(), 'test');
  assert.equal(requests[1].params.alt, 'media');
});

test('rejects Drive downloads outside the configured folder', async () => {
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_DRIVE_TEST_FOLDER_ID: '1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_',
    },
    authClient: {
      async request() {
        return {
          data: {
            id: 'outside-file-123',
            name: 'private.pdf',
            mimeType: 'application/pdf',
            size: '4',
            parents: ['another-folder'],
            trashed: false,
          },
        };
      },
    },
  });
  await assert.rejects(
    () => sheets.downloadDriveFile('outside-file-123'),
    /outside the configured folder/,
  );
});

test('creates a Drive test file under the configured folder', async () => {
  const authClient = {
    async request(options) {
      assert.equal(options.method, 'POST');
      assert.deepEqual(options.data.parents, ['1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_']);
      assert.equal(options.data.mimeType, 'text/plain');
      return { data: { id: 'file-2', name: options.data.name, mimeType: 'text/plain' } };
    },
  };
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_DRIVE_TEST_FOLDER_ID: '1dhO2ORwDH5Ue9FAMfo3LLer_Dgj70ck_',
    },
    authClient,
  });
  const file = await sheets.createDriveTestFile('safe-test.txt', 'test contents');
  assert.equal(file.id, 'file-2');
  await assert.rejects(
    () => sheets.createDriveTestFile('../unsafe.txt'),
    /invalid/,
  );
});

test('creates an idempotent company folder structure with department and employee folders', async () => {
  const folders = new Map();
  let sequence = 0;
  const authClient = {
    async request(options) {
      if (options.method === 'GET' && options.url.endsWith('/files')) {
        const parent = /'([^']+)' in parents/.exec(options.params.q)?.[1];
        const name = /name = '([^']+)'/.exec(options.params.q)?.[1];
        const folder = folders.get(`${parent}:${name}`);
        return { data: { files: folder ? [folder] : [] } };
      }
      if (options.method === 'POST' && options.url.endsWith('/files')) {
        const folder = { id: `folder-${++sequence}`, name: options.data.name };
        folders.set(`${options.data.parents[0]}:${folder.name}`, folder);
        return { data: folder };
      }
      throw new Error(`Unexpected request: ${options.method} ${options.url}`);
    },
  };
  const integration = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_WORKSPACE_ROOT_FOLDER_ID: '1x29BNYQp2rR8x7WUSkHZxh6t36CHGOp_',
    },
    authClient,
  });
  const first = await integration.ensureCompanyWorkspaceStructure({
    departments: ['Sales', 'IT', 'Sales'],
    employees: [
      { employeeId: 'IT-400', displayName: 'ندى', department: 'IT' },
      { employeeId: 'CEO-100', displayName: 'محمد', department: 'Sales' },
    ],
  });
  assert.equal(first.created, 11);
  assert.equal(first.departmentFolders, 2);
  assert.equal(first.employeeFolders, 2);
  const second = await integration.ensureCompanyWorkspaceStructure({
    departments: ['Sales', 'IT'],
    employees: [{ employeeId: 'IT-400', displayName: 'ندى', department: 'IT' }],
  });
  assert.equal(second.created, 0);
  assert.equal(second.departmentFolders, 0);
  assert.equal(second.employeeFolders, 0);
});

test('an editor can add, rename, and delete worksheet tabs', async () => {
  const requests = [];
  let tabs = [
    { properties: { title: 'Sheet1', sheetId: 1, index: 0 } },
  ];
  const authClient = {
    async request(options) {
      requests.push(options);
      if (options.method === 'GET') {
        return { data: { sheets: tabs } };
      }
      const command = options.data.requests[0];
      if (command.addSheet) {
        const created = {
          properties: { title: command.addSheet.properties.title, sheetId: 2, index: 1 },
        };
        tabs = [...tabs, created];
        return { data: { replies: [{ addSheet: created }] } };
      }
      if (command.updateCells) return { data: { replies: [{}] } };
      if (command.updateSheetProperties) {
        tabs[1].properties.title = command.updateSheetProperties.properties.title;
        return { data: { replies: [{}] } };
      }
      if (command.deleteSheet) {
        tabs = tabs.filter((tab) => tab.properties.sheetId !== command.deleteSheet.sheetId);
        return { data: { replies: [{}] } };
      }
      throw new Error(`Unexpected request: ${JSON.stringify(command)}`);
    },
  };
  const integration = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
    },
    authClient,
  });

  assert.deepEqual(
    await integration.changeWorkspaceSheetTab({
      spreadsheetId: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      operation: 'add',
      newName: 'Sheet2',
    }),
    { tabName: 'Sheet2' },
  );
  assert.equal(tabs.length, 2);
  assert.ok(requests.some((item) => item.data?.requests?.[0]?.updateCells));

  assert.deepEqual(
    await integration.changeWorkspaceSheetTab({
      spreadsheetId: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      operation: 'rename',
      tabName: 'Sheet2',
      newName: 'Tasks',
    }),
    { tabName: 'Tasks' },
  );
  assert.equal(tabs[1].properties.title, 'Tasks');

  assert.deepEqual(
    await integration.changeWorkspaceSheetTab({
      spreadsheetId: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      operation: 'delete',
      tabName: 'Tasks',
    }),
    { tabName: 'Sheet1' },
  );
  assert.equal(tabs.length, 1);
});

test('workspace edit grants include structure and worksheet-tab editing', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );
  assert.match(source, /structure: item\.canEdit/);
  assert.match(source, /parts\[4\] === 'tabs'/);
  assert.match(source, /changeWorkspaceSheetTab/);
});

test('Hostinger verifies app tokens with the modular Firebase Auth API', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );
  assert.match(source, /require\('firebase-admin\/auth'\)/);
  assert.match(source, /getAuth\(firebaseApp\)\.verifyIdToken\(token\)/);
  assert.doesNotMatch(source, /admin\.auth\(\)\.verifyIdToken/);
});

test('daily HR reports replace one dated Google Sheet tab without CSV', async () => {
  const requests = [];
  const authClient = {
    async request(options) {
      requests.push(options);
      if (options.method === 'GET') {
        return { data: { sheets: [{ properties: { sheetId: 12, title: 'Daily_2026-08-12' } }] } };
      }
      return { data: {} };
    },
  };
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_HR_REPORTS_SPREADSHEET_ID: '1reportsWorkbookId1234567890',
    },
    authClient,
  });
  const report = await sheets.writeDailyReport(
    '2026-08-12',
    ['التاريخ', 'الموظف'],
    [['2026-08-12', 'أحمد']],
  );
  assert.equal(report.tabTitle, 'Daily_2026-08-12');
  assert.equal(report.rowCount, 1);
  assert.equal(requests.some((item) => item.url.endsWith(':clear')), true);
  const write = requests.find((item) => item.method === 'PUT');
  assert.deepEqual(write.data.values, [
    ['التاريخ', 'الموظف'],
    ['2026-08-12', 'أحمد'],
  ]);
  const formatting = requests.find(
    (item) => item.method === 'POST' &&
      item.url.endsWith(':batchUpdate') &&
      item.data.requests?.some((request) => request.setBasicFilter),
  );
  assert.ok(formatting);
  assert.equal(
    formatting.data.requests[0].updateSheetProperties.properties.rightToLeft,
    true,
  );
});

test('Workspace reports reuse the company-owned reports workbook when configured', async () => {
  const requests = [];
  const authClient = {
    async request(options) {
      requests.push(options);
      if (options.method === 'GET') {
        return { data: { sheets: [{ properties: { sheetId: 9, title: 'سجل التدقيق' } }] } };
      }
      return { data: {} };
    },
  };
  const sheets = createGoogleSheetsIntegration({
    env: {
      GOOGLE_SHEETS_TEST_SPREADSHEET_ID: '1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM',
      GOOGLE_HR_REPORTS_SPREADSHEET_ID: '1reportsWorkbookId1234567890',
      GOOGLE_WORKSPACE_ROOT_FOLDER_ID: 'companyRootFolderId123',
    },
    authClient,
  });
  const report = await sheets.writeWorkspaceAuditReport(['الإجراء'], [['عرض']]);
  assert.equal(report.spreadsheetId, '1reportsWorkbookId1234567890');
  assert.equal(report.rowCount, 1);
  assert.equal(requests.some((item) => String(item.url).includes('/drive/v3/files')), false);
  assert.equal(requests.some((item) => item.method === 'PUT'), true);
});
