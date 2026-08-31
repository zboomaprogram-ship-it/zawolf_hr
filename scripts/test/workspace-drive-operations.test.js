const test = require('node:test');
const assert = require('node:assert/strict');
const { performWorkspaceDriveOperation } = require('../workspace/drive-operations');
const {
  reserveWorkspaceOperation,
  completeWorkspaceOperation,
} = require('../workspace/operation-idempotency');

function fakeDb() {
  const values = new Map();
  return {
    collection(name) {
      return {
        doc(id) {
          const key = `${name}/${id}`;
          return {
            async get() {
              const value = values.get(key);
              return { exists: value != null, data: () => value };
            },
            async create(value) {
              if (values.has(key)) {
                const error = new Error('already exists');
                error.code = 'already_exists';
                throw error;
              }
              values.set(key, value);
            },
            async update(value) {
              values.set(key, { ...values.get(key), ...value });
            },
          };
        },
      };
    },
  };
}

test('a create-folder operation uses only the verified parent folder', async () => {
  const calls = [];
  const connector = {
    async createWorkspaceDriveFolder(input) {
      calls.push(input);
      return { id: 'new-folder', name: input.name };
    },
  };
  const result = await performWorkspaceDriveOperation({
    connector,
    sourceFolderId: 'verified_parent',
    kind: 'fileCreate',
    payload: { name: 'مجلد جديد', untrustedParentId: 'do-not-use' },
  });
  assert.equal(result.action, 'file_create');
  assert.deepEqual(calls, [{ parentFolderId: 'verified_parent', name: 'مجلد جديد' }]);
});

test('move requires a verified destination and never accepts one from payload', async () => {
  await assert.rejects(
    performWorkspaceDriveOperation({
      connector: {}, sourceFolderId: 'source', kind: 'fileMove',
      payload: { fileId: 'file-id', destinationFolderId: 'untrusted' },
    }),
    (error) => error.code === 'validation',
  );
});

test('trash has no result data and routes through the checked parent', async () => {
  const calls = [];
  const result = await performWorkspaceDriveOperation({
    connector: { async trashWorkspaceDriveFile(input) { calls.push(input); } },
    sourceFolderId: 'verified_parent', kind: 'fileTrash', payload: { fileId: 'child-file' },
  });
  assert.equal(result.action, 'file_trash');
  assert.deepEqual(calls, [{ parentFolderId: 'verified_parent', fileId: 'child-file' }]);
});

test('upload, rename, copy and restore remain provider-neutral operations', async () => {
  const calls = [];
  const connector = {
    async uploadWorkspaceDriveFile(input) {
      calls.push(['upload', input]);
      return { id: 'upload-1', name: input.name };
    },
    async renameWorkspaceDriveFile(input) {
      calls.push(['rename', input]);
      return { id: input.fileId, name: input.name };
    },
    async copyWorkspaceDriveFile(input) {
      calls.push(['copy', input]);
      return { id: 'copy-1', name: 'نسخة' };
    },
    async restoreWorkspaceDriveFile(input) {
      calls.push(['restore', input]);
      return { id: input.fileId, trashed: false };
    },
  };

  const common = { connector, sourceFolderId: 'verified_source' };
  const upload = await performWorkspaceDriveOperation({
    ...common,
    kind: 'fileUpload',
    payload: { name: 'ملف.txt', mimeType: 'text/plain', contentsBase64: 'aGVsbG8=' },
  });
  const rename = await performWorkspaceDriveOperation({
    ...common, kind: 'fileRename', payload: { fileId: 'file-1', name: 'جديد.txt' },
  });
  const copy = await performWorkspaceDriveOperation({
    ...common, kind: 'fileCopy', destinationFolderId: 'verified_destination',
    payload: { fileId: 'file-1', name: 'نسخة' },
  });
  const restore = await performWorkspaceDriveOperation({
    ...common, kind: 'fileRestore', payload: { fileId: 'file-1' },
  });

  assert.deepEqual(
    [upload.action, rename.action, copy.action, restore.action],
    ['file_upload', 'file_rename', 'file_copy', 'file_restore'],
  );
  assert.deepEqual(calls, [
    ['upload', { parentFolderId: 'verified_source', name: 'ملف.txt', mimeType: 'text/plain', contentsBase64: 'aGVsbG8=' }],
    ['rename', { parentFolderId: 'verified_source', fileId: 'file-1', name: 'جديد.txt' }],
    ['copy', { parentFolderId: 'verified_source', destinationFolderId: 'verified_destination', fileId: 'file-1', name: 'نسخة' }],
    ['restore', { parentFolderId: 'verified_source', fileId: 'file-1' }],
  ]);
});

test('every Drive mutation kind replays its idempotent receipt without a second execution', async () => {
  const db = fakeDb();
  const kinds = ['fileCreate', 'fileUpload', 'fileRename', 'fileMove', 'fileCopy', 'fileTrash', 'fileRestore'];
  let executions = 0;
  for (const kind of kinds) {
    const input = {
      db,
      operationId: `drive_${kind}_operation_0001`,
      actorId: 'actor-1',
      resourceId: 'resource-1',
    };
    const first = await reserveWorkspaceOperation(input);
    if (first.kind === 'new') {
      executions += 1;
      await completeWorkspaceOperation({
        reservation: first,
        result: { state: 'acknowledged', safeMessage: 'تم الحفظ.' },
      });
    }
    const retry = await reserveWorkspaceOperation(input);
    assert.equal(retry.kind, 'replay', kind);
    assert.equal(retry.receipt.state, 'acknowledged', kind);
  }
  assert.equal(executions, kinds.length);
});
