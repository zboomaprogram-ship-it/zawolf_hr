'use strict';

// Chat media is private: the Hostinger API remains the authorization boundary.
// Objects are never exposed through Firebase Storage client rules or public URLs.
const crypto = require('node:crypto');
const admin = require('firebase-admin');
const MAX_BYTES = 25 * 1024 * 1024;
const PREFIX = 'gcs_';

function isFirebaseMediaId(fileId) {
  return String(fileId || '').startsWith(PREFIX);
}

function objectName(fileId) {
  if (!isFirebaseMediaId(fileId)) throw new Error('invalid_media_id');
  return `conversation-media/${fileId}`;
}

function validateSessionUri(raw) {
  const url = new URL(String(raw));
  const validHost = url.hostname === 'storage.googleapis.com' || url.hostname === 'www.googleapis.com';
  if (url.protocol !== 'https:' || !validHost || url.username || url.password) {
    throw new Error('invalid_upload_session');
  }
  return url.href;
}

function progress(response, total) {
  if (response.status === 308) {
    const range = response.headers.get('range') || '';
    const match = /^bytes=0-(\d+)$/.exec(range);
    return { offset: match ? Number(match[1]) + 1 : 0, complete: false };
  }
  return { offset: total, complete: true };
}

function createFirebaseStorageMediaProvider({ bucket, bucketName } = {}) {
  // Firebase projects created after October 2024 use the .firebasestorage.app
  // bucket. Keep this explicit so the Hostinger service does not silently target
  // the legacy .appspot.com bucket.
  const configuredBucket = bucketName || process.env.FIREBASE_STORAGE_BUCKET ||
    `${admin.app().options.projectId || process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID}.firebasestorage.app`;
  const storageBucket = bucket || admin.storage().bucket(configuredBucket);
  const fileFor = (fileId) => storageBucket.file(objectName(fileId));

  return {
    requiresFolder: false,
    async allocateId() {
      return `${PREFIX}${crypto.randomBytes(18).toString('hex')}`;
    },
    async start({ fileId, fileName, mimeType, sizeBytes }) {
      const file = fileFor(fileId);
      const [uri] = await file.createResumableUpload({
        metadata: {
          contentType: mimeType,
          metadata: { originalFileName: fileName, sizeBytes: String(sizeBytes) },
        },
        validation: false,
        origin: 'https://notification.zawolf.ai',
      });
      return validateSessionUri(uri);
    },
    async status({ sessionUri, sizeBytes }) {
      const response = await fetch(validateSessionUri(sessionUri), {
        method: 'PUT',
        headers: { 'content-length': '0', 'content-range': `bytes */${sizeBytes}` },
      });
      if (!response.ok && response.status !== 308) throw new Error(`storage_status_${response.status}`);
      return progress(response, sizeBytes);
    },
    async chunk({ sessionUri, offset, bytes, sizeBytes }) {
      const response = await fetch(validateSessionUri(sessionUri), {
        method: 'PUT',
        headers: {
          'content-length': String(bytes.length),
          'content-range': `bytes ${offset}-${offset + bytes.length - 1}/${sizeBytes}`,
        },
        body: bytes,
      });
      if (!response.ok && response.status !== 308) throw new Error(`storage_chunk_${response.status}`);
      return progress(response, sizeBytes);
    },
    async metadata({ fileId }) {
      try {
        const [metadata] = await fileFor(fileId).getMetadata();
        if (Number(metadata.size) > MAX_BYTES) throw new Error('attachment_unavailable');
        return {
          id: fileId,
          name: metadata.metadata?.originalFileName || fileId,
          mimeType: metadata.contentType || 'application/octet-stream',
          size: metadata.size,
          parents: ['firebase_storage'],
        };
      } catch (error) {
        if (Number(error?.code) === 404) return null;
        throw error;
      }
    },
    async download({ fileId }) {
      const metadata = await this.metadata({ fileId });
      if (!metadata) throw new Error('attachment_unavailable');
      const [contents] = await fileFor(fileId).download({ validation: false });
      if (contents.length > MAX_BYTES) throw new Error('too_large');
      return { contents, fileName: metadata.name, mimeType: metadata.mimeType };
    },
  };
}

module.exports = { createFirebaseStorageMediaProvider, isFirebaseMediaId };
