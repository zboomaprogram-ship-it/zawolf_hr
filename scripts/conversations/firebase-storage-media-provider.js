'use strict';

const crypto = require('node:crypto');

const MAX_BYTES = 25 * 1024 * 1024;
const OBJECT_ROOT = 'conversation-attachments';

function failure(code, status = 500) {
  const error = new Error(code);
  error.code = code;
  error.status = status;
  return error;
}

function uploadSession(value) {
  const raw = String(value || '');
  if (!raw.startsWith('gcs:')) throw failure('invalid_upload_session', 400);
  try {
    const session = JSON.parse(Buffer.from(raw.slice(4), 'base64url').toString('utf8'));
    if (!/^gcs_[a-f0-9]{32}$/.test(session.fileId) ||
        !Number.isSafeInteger(session.sizeBytes) || session.sizeBytes < 1 ||
        session.sizeBytes > MAX_BYTES) {
      throw new Error('invalid');
    }
    return session;
  } catch (_) {
    throw failure('invalid_upload_session', 400);
  }
}

function objectPath(fileId) {
  if (!/^gcs_[a-f0-9]{32}$/.test(String(fileId || ''))) {
    throw failure('attachment_unavailable', 404);
  }
  return `${OBJECT_ROOT}/${fileId}`;
}

function partPath(session, offset) {
  return `${objectPath(session.fileId)}.parts/${String(offset).padStart(10, '0')}`;
}

async function exists(file) {
  const [present] = await file.exists();
  return present;
}

async function contiguousOffset(bucket, session) {
  const [files] = await bucket.getFiles({prefix: `${objectPath(session.fileId)}.parts/`});
  const parts = [];
  for (const file of files) {
    const offset = Number(file.name.split('/').pop());
    if (!Number.isSafeInteger(offset) || offset < 0) continue;
    const [metadata] = await file.getMetadata();
    parts.push({offset, size: Number(metadata.size || 0), file});
  }
  parts.sort((a, b) => a.offset - b.offset);
  let offset = 0;
  const sources = [];
  for (const part of parts) {
    if (part.offset !== offset || part.size < 1) break;
    sources.push(part.file);
    offset += part.size;
  }
  return {offset, sources};
}

function createFirebaseStorageMediaProvider({bucket}) {
  if (!bucket) throw new Error('firebase_storage_bucket_missing');

  async function metadata({fileId, folderId}) {
    const file = bucket.file(objectPath(fileId));
    try {
      const [data] = await file.getMetadata();
      if (String(data.metadata?.conversationContainer || '') !== String(folderId || '') ||
          Number(data.size || 0) > MAX_BYTES) {
        throw failure('attachment_unavailable', 404);
      }
      return {
        id: fileId,
        name: String(data.metadata?.originalFileName || fileId),
        mimeType: String(data.contentType || 'application/octet-stream'),
        size: Number(data.size || 0),
        parents: [folderId],
        trashed: false,
      };
    } catch (error) {
      if (Number(error?.code) === 404) return null;
      throw error;
    }
  }

  return {
    name: 'firebase_storage',
    containerId: 'firebase-storage-conversation-attachments-v1',
    providerFor: () => 'firebase_storage',
    async allocateId() {
      return `gcs_${crypto.randomBytes(16).toString('hex')}`;
    },
    async start({fileId, folderId, fileName, mimeType, sizeBytes}) {
      objectPath(fileId);
      const session = {fileId, folderId, fileName, mimeType, sizeBytes};
      return `gcs:${Buffer.from(JSON.stringify(session)).toString('base64url')}`;
    },
    async status({sessionUri, sizeBytes}) {
      const session = uploadSession(sessionUri);
      const completed = await metadata({fileId: session.fileId, folderId: session.folderId});
      if (completed) return {offset: sizeBytes, complete: true};
      const state = await contiguousOffset(bucket, session);
      return {offset: state.offset, complete: false};
    },
    async chunk({sessionUri, offset, bytes, sizeBytes}) {
      const session = uploadSession(sessionUri);
      if (session.sizeBytes !== sizeBytes || offset + bytes.length > sizeBytes) {
        throw failure('upload_size_mismatch', 409);
      }
      const part = bucket.file(partPath(session, offset));
      await part.save(bytes, {resumable: false, metadata: {contentType: 'application/octet-stream'}});
      const state = await contiguousOffset(bucket, session);
      if (state.offset < sizeBytes) return {offset: state.offset, complete: false};
      if (state.offset !== sizeBytes) throw failure('upload_size_mismatch', 409);

      const destination = bucket.file(objectPath(session.fileId));
      await bucket.combine(state.sources, destination);
      await destination.setMetadata({
        contentType: session.mimeType,
        metadata: {
          conversationContainer: String(session.folderId),
          originalFileName: String(session.fileName),
        },
      });
      await Promise.allSettled(state.sources.map((source) => source.delete()));
      return {offset: sizeBytes, complete: true};
    },
    metadata,
    async download({fileId, folderId}) {
      const data = await metadata({fileId, folderId});
      if (!data) throw failure('attachment_unavailable', 404);
      const [contents] = await bucket.file(objectPath(fileId)).download();
      if (contents.length > MAX_BYTES) throw failure('too_large', 413);
      return {contents, fileName: data.name, mimeType: data.mimeType};
    },
  };
}

module.exports = {createFirebaseStorageMediaProvider, uploadSession};
