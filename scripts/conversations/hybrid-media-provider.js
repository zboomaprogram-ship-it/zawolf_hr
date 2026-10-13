'use strict';
const { createFirebaseStorageMediaProvider, isFirebaseMediaId } = require('./firebase-storage-media-provider');

// New media uses Cloud Storage. Legacy Drive/local attachment ids retain their
// original provider so existing chat history remains readable after migration.
function createHybridMediaProvider({ driveProvider, firebaseProvider } = {}) {
  const cloud = firebaseProvider || createFirebaseStorageMediaProvider();
  if (!driveProvider) throw new Error('drive_provider_required');
  const providerForId = (fileId) => isFirebaseMediaId(fileId) ? cloud : driveProvider;
  const providerForSession = (sessionUri) => {
    const raw = String(sessionUri || '');
    return raw.includes('storage.googleapis.com') || raw.includes('www.googleapis.com/upload/storage/') ? cloud : driveProvider;
  };
  return {
    requiresFolder: false,
    providerForId,
    async allocateId() { return cloud.allocateId(); },
    async start(input) { return providerForId(input.fileId).start(input); },
    async status(input) { return providerForSession(input.sessionUri).status(input); },
    async chunk(input) { return providerForSession(input.sessionUri).chunk(input); },
    async metadata(input) { return providerForId(input.fileId).metadata(input); },
    async download(input) { return providerForId(input.fileId).download(input); },
    // Only old Drive error handling calls this method. New Cloud Storage uploads
    // deliberately fail safely instead of falling back to transient server disk.
    async startLocal(input) { return driveProvider.startLocal(input); },
  };
}
module.exports = { createHybridMediaProvider };
