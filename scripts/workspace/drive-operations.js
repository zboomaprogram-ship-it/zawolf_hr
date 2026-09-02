function validationError() {
  const error = new Error('Workspace operation is invalid.');
  error.code = 'validation';
  return error;
}

function requiredString(payload, key, maxLength = 512) {
  const value = String(payload?.[key] || '').trim();
  if (!value || value.length > maxLength) throw validationError();
  return value;
}

/// Executes only provider calls.  Authorization and navigation verification
/// intentionally stay in the HTTP boundary, before a Drive id reaches here.
async function performWorkspaceDriveOperation({
  connector,
  sourceFolderId,
  destinationFolderId,
  kind,
  payload,
}) {
  switch (kind) {
    case 'fileCreate':
      return {
        action: 'file_create',
        result: await connector.createWorkspaceDriveFolder({
          parentFolderId: sourceFolderId,
          name: requiredString(payload, 'name', 160),
        }),
      };
    case 'fileUpload':
      return {
        action: 'file_upload',
        result: await connector.uploadWorkspaceDriveFile({
          parentFolderId: sourceFolderId,
          name: requiredString(payload, 'name', 160),
          mimeType: requiredString(payload, 'mimeType', 120),
          contentsBase64: requiredString(payload, 'contentsBase64', 29 * 1024 * 1024),
        }),
      };
    case 'fileRename':
      return {
        action: 'file_rename',
        result: await connector.renameWorkspaceDriveFile({
          parentFolderId: sourceFolderId,
          fileId: requiredString(payload, 'fileId', 160),
          name: requiredString(payload, 'name', 160),
        }),
      };
    case 'fileMove':
      if (!destinationFolderId) throw validationError();
      return {
        action: 'file_move',
        result: await connector.moveWorkspaceDriveFile({
          oldParentFolderId: sourceFolderId,
          newParentFolderId: destinationFolderId,
          fileId: requiredString(payload, 'fileId', 160),
        }),
      };
    case 'fileCopy':
      if (!destinationFolderId) throw validationError();
      return {
        action: 'file_copy',
        result: await connector.copyWorkspaceDriveFile({
          parentFolderId: sourceFolderId,
          destinationFolderId,
          fileId: requiredString(payload, 'fileId', 160),
          name: String(payload?.name || '').trim(),
        }),
      };
    case 'fileTrash':
      await connector.trashWorkspaceDriveFile({
        parentFolderId: sourceFolderId,
        fileId: requiredString(payload, 'fileId', 160),
      });
      return { action: 'file_trash', result: {} };
    case 'fileRestore':
      return {
        action: 'file_restore',
        result: await connector.restoreWorkspaceDriveFile({
          parentFolderId: sourceFolderId,
          fileId: requiredString(payload, 'fileId', 160),
        }),
      };
    default:
      throw validationError();
  }
}

/// Conversation attachments use the same provider boundary as Company
/// Workspace files, but deliberately expose only an opaque application
/// resource id to callers. Membership and audit checks stay at the HTTP
/// boundary; this helper owns the provider operation only.
async function uploadGovernedAttachment({
  connector,
  parentFolderId,
  payload,
  useDriveUploadOAuth = false,
}) {
  return connector.uploadWorkspaceDriveFile({
    parentFolderId: requiredString({ parentFolderId }, 'parentFolderId', 256),
    name: requiredString(payload, 'name', 160),
    mimeType: requiredString(payload, 'mimeType', 120),
    contentsBase64: requiredString(
      payload,
      'contentsBase64',
      14 * 1024 * 1024,
    ),
    useDriveUploadOAuth,
  });
}

async function downloadGovernedAttachment({
  connector,
  parentFolderId,
  externalFileId,
  useDriveUploadOAuth = false,
}) {
  return connector.downloadWorkspaceDriveFile({
    folderId: requiredString({ parentFolderId }, 'parentFolderId', 256),
    fileId: requiredString({ externalFileId }, 'externalFileId', 256),
    useDriveUploadOAuth,
  });
}

module.exports = {
  performWorkspaceDriveOperation,
  uploadGovernedAttachment,
  downloadGovernedAttachment,
  requiredString,
};
