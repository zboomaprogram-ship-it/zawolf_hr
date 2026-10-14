'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeUpload, validateChunk, sniffMime, validateVoiceMime } = require('../conversations/uploads');
const { createDriveMediaProvider } = require('../conversations/drive-media-provider');
test('upload boundaries and unsafe metadata are rejected', () => {
  const input = {operationId:'upload-1',fileName:'صورة.png',mimeType:'image/png',sizeBytes:25*1024*1024};
  assert.equal(normalizeUpload(input).sizeBytes, input.sizeBytes);
  for (const change of [{sizeBytes:0},{sizeBytes:input.sizeBytes+1},{fileName:'../secret'},{mimeType:'text/html\r\nx:1'},{operationId:'bad/path'}]) {
    assert.throws(()=>normalizeUpload({...input,...change}));
  }
  const thumbnail='data:image/jpeg;base64,'+Buffer.alloc(100).toString('base64');
  assert.equal(normalizeUpload({...input,thumbnailBase64:thumbnail}).thumbnailBase64,thumbnail);
  assert.throws(()=>normalizeUpload({...input,thumbnailBase64:'data:text/html;base64,AAAA'}));
});
test('chunk offsets and final length cannot exceed declared upload', () => {
  assert.doesNotThrow(()=>validateChunk(0,1024,1024));
  assert.throws(()=>validateChunk(-1,1,1024));
  assert.throws(()=>validateChunk(0,1024*1024+1,25*1024*1024));
  assert.throws(()=>validateChunk(1000,25,1024));
  assert.equal(sniffMime(Buffer.from([137,80,78,71,13,10,26,10]),'image/jpeg'),'image/png');
  assert.equal(sniffMime(Buffer.from([0,0,0,24,102,116,121,112,104,101,105,99]),'image/heic'),'image/heic');
  assert.equal(sniffMime(Buffer.from('<script>bad</script>'),'image/png'),'application/octet-stream');
});
test('voice uploads accept formats produced by native and web recorders', () => {
  for (const mime of ['audio/wav','audio/webm','audio/mp4','audio/ogg','audio/mpeg']) {
    assert.doesNotThrow(()=>validateVoiceMime('voice',mime));
  }
  assert.throws(()=>validateVoiceMime('voice','application/octet-stream'), /invalid_voice/);
  assert.doesNotThrow(()=>validateVoiceMime(null,'application/octet-stream'));
});
test('resumable Drive provider retains generated ID and never leaks session in result', async () => {
  const calls=[];
  const request = async (o) => {
    calls.push(o);
    if(o.url.endsWith('/generateIds')) return {data:{ids:['provider-123']}};
    if(o.method==='POST') return {headers:{location:'https://www.googleapis.com/upload/drive/v3/files?upload_id=private'}};
    if(o.headers?.['content-range']==='bytes */1024') return {status:308,headers:{range:'bytes=0-511'}};
    return {status:200,data:{id:'provider-123',size:'1024',mimeType:'image/png',parents:['folder']}};
  };
  const p=createDriveMediaProvider({request});
  const id=await p.allocateId();
  assert.equal(id,'provider-123');
  const session=await p.start({fileId:id,folderId:'folder',fileName:'x.png',mimeType:'image/png',sizeBytes:1024});
  assert.equal(calls[1].data.id,id);
  assert.deepEqual(await p.status({sessionUri:session,sizeBytes:1024}),{offset:512,complete:false});
  assert.deepEqual(await p.chunk({sessionUri:session,offset:512,bytes:Buffer.alloc(512),sizeBytes:1024}),{offset:1024,complete:true});
  await assert.rejects(()=>p.status({sessionUri:'http://127.0.0.1/private',sizeBytes:1024}));
});
test('drive provider gracefully falls back to local storage on quota exhaustion', async () => {
  const quotaErr = new Error('Service Accounts do not have storage quota. Leverage shared drives or use OAuth delegation instead.');
  quotaErr.response = { status: 403, data: { error: { message: quotaErr.message } } };

  const request = async () => {
    throw quotaErr;
  };
  const p = createDriveMediaProvider({ request });
  const id = 'quota-test-file-' + Date.now();
  const session = await p.start({ fileId: id, folderId: 'folder', fileName: 'test.jpg', mimeType: 'image/jpeg', sizeBytes: 500 });
  assert.equal(session.startsWith('local://'), true);

  const status = await p.status({ sessionUri: session, sizeBytes: 500 });
  assert.equal(status.complete, false);
  assert.equal(status.offset, 0);

  const chunkResult = await p.chunk({ sessionUri: session, offset: 0, bytes: Buffer.alloc(500), sizeBytes: 500 });
  assert.equal(chunkResult.complete, true);
  assert.equal(chunkResult.offset, 500);

  const meta = await p.metadata({ fileId: id, folderId: 'folder' });
  assert.equal(meta.id, id);
  assert.equal(meta.name, 'test.jpg');

  const downloaded = await p.download({ fileId: id, folderId: 'folder' });
  assert.equal(downloaded.contents.length, 500);
  assert.equal(downloaded.fileName, 'test.jpg');
});
test('drive provider gracefully falls back to local storage on unusable file ID', async () => {
  const fileIdErr = new Error('The provided file ID is not usable.');
  fileIdErr.response = { status: 400, data: { error: { message: fileIdErr.message } } };

  const request = async () => {
    throw fileIdErr;
  };
  const p = createDriveMediaProvider({ request });
  const id = 'unusable-id-test-' + Date.now();
  const session = await p.start({ fileId: id, folderId: 'folder', fileName: 'voice.wav', mimeType: 'audio/wav', sizeBytes: 300 });
  assert.equal(session.startsWith('local://'), true);

  const chunkResult = await p.chunk({ sessionUri: session, offset: 0, bytes: Buffer.alloc(300), sizeBytes: 300 });
  assert.equal(chunkResult.complete, true);
  assert.equal(chunkResult.offset, 300);

  const downloaded = await p.download({ fileId: id, folderId: 'folder' });
  assert.equal(downloaded.contents.length, 300);
  assert.equal(downloaded.fileName, 'voice.wav');
});

test('drive provider downloads via arraybuffer and follows redirects', async () => {
  const fileBytes = Buffer.from('mock binary audio wav file payload');
  const calls = [];
  const request = async (o) => {
    calls.push(o);
    if (o.url.includes('/files/drive-download-id') && o.params?.fields) {
      return { status: 200, data: { id: 'drive-download-id', name: 'recording.wav', mimeType: 'audio/wav', size: String(fileBytes.length), parents: ['folder'] } };
    }
    if (o.params?.alt === 'media') {
      assert.equal(o.responseType, 'arraybuffer');
      assert.equal(o.maxRedirects, 5);
      return { status: 200, data: fileBytes };
    }
    throw new Error('unexpected request: ' + o.url);
  };
  const p = createDriveMediaProvider({ request });
  const result = await p.download({ fileId: 'drive-download-id', folderId: 'folder' });
  assert.equal(result.fileName, 'recording.wav');
  assert.equal(result.mimeType, 'audio/wav');
  assert.deepEqual(result.contents, fileBytes);

  // Subsequent download uses local cache without calling provider request again
  const callsBefore = calls.length;
  const cached = await p.download({ fileId: 'drive-download-id', folderId: 'folder' });
  assert.equal(calls.length, callsBefore);
  assert.deepEqual(cached.contents, fileBytes);
});




test('hybrid provider writes new media to Firebase Storage and keeps legacy Drive reads', async () => {
  const { createHybridMediaProvider } = require('../conversations/hybrid-media-provider');
  const calls = [];
  const drive = {
    allocateId: async () => 'drive-new',
    start: async () => { calls.push('drive-start'); return 'https://www.googleapis.com/upload/drive/v3/files?upload_id=legacy'; },
    status: async () => ({ offset: 0, complete: false }),
    chunk: async () => ({ offset: 1, complete: true }),
    metadata: async ({ fileId }) => { calls.push(`drive-meta:${fileId}`); return { id:fileId, size:'1' }; },
    download: async ({ fileId }) => { calls.push(`drive-download:${fileId}`); return { contents:Buffer.from('old'), fileName:'old', mimeType:'text/plain' }; },
    startLocal: async () => 'local://legacy',
  };
  const cloud = {
    requiresFolder:false,
    allocateId: async () => 'gcs_new',
    start: async () => { calls.push('cloud-start'); return 'https://storage.googleapis.com/upload/storage/v1/b/bucket/o?upload_id=new'; },
    status: async () => ({ offset: 0, complete: false }),
    chunk: async () => ({ offset: 1, complete: true }),
    metadata: async ({ fileId }) => { calls.push(`cloud-meta:${fileId}`); return { id:fileId, size:'1' }; },
    download: async ({ fileId }) => { calls.push(`cloud-download:${fileId}`); return { contents:Buffer.from('new'), fileName:'new', mimeType:'text/plain' }; },
  };
  const provider = createHybridMediaProvider({ driveProvider:drive, firebaseProvider:cloud });
  assert.equal(provider.supportsDirectUpload, true);
  const id = await provider.allocateId();
  assert.equal(id, 'gcs_new');
  await provider.start({ fileId:id });
  await provider.download({ fileId:'legacy-drive-id' });
  await provider.download({ fileId:id });
  assert.deepEqual(calls, ['cloud-start', 'drive-download:legacy-drive-id', 'cloud-download:gcs_new']);
});

test('Firebase media provider uses the explicit modern Firebase bucket', () => {
  const Module = require('node:module');
  const originalLoad = Module._load;
  let requestedBucket = null;
  Module._load = function (request, parent, isMain) {
    if (request === 'firebase-admin') {
      return {
        app: () => ({ options: { projectId: 'demo-project' } }),
        storage: () => ({ bucket: (name) => { requestedBucket = name; return { file: () => ({}) }; } }),
      };
    }
    return originalLoad.call(this, request, parent, isMain);
  };
  const modulePath = require.resolve('../conversations/firebase-storage-media-provider');
  delete require.cache[modulePath];
  const { createFirebaseStorageMediaProvider } = require('../conversations/firebase-storage-media-provider');
  createFirebaseStorageMediaProvider();
  assert.equal(requestedBucket, 'demo-project.firebasestorage.app');
  delete require.cache[modulePath];
  Module._load = originalLoad;
});
