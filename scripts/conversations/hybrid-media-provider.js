'use strict';

function createHybridMediaProvider({primary, legacy}) {
  const isPrimaryId = (value) => String(value || '').startsWith('gcs_');
  const isPrimarySession = (value) => String(value || '').startsWith('gcs:');
  return {
    name: primary.name,
    containerId: primary.containerId,
    providerFor: (fileId) => isPrimaryId(fileId) ? primary.name : legacy.name,
    allocateId: (...args) => primary.allocateId(...args),
    start: (args) => (isPrimaryId(args.fileId) ? primary : legacy).start(args),
    status: (args) => (isPrimarySession(args.sessionUri) ? primary : legacy).status(args),
    chunk: (args) => (isPrimarySession(args.sessionUri) ? primary : legacy).chunk(args),
    metadata: (args) => (isPrimaryId(args.fileId) ? primary : legacy).metadata(args),
    download: (args) => (isPrimaryId(args.fileId) ? primary : legacy).download(args),
  };
}

module.exports = {createHybridMediaProvider};
