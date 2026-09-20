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
});
test('chunk offsets and final length cannot exceed declared upload', () => {
  assert.doesNotThrow(()=>validateChunk(0,1024,1024));
  assert.throws(()=>validateChunk(-1,1,1024));
  assert.throws(()=>validateChunk(0,1024*1024+1,25*1024*1024));
  assert.throws(()=>validateChunk(1000,25,1024));
  assert.equal(sniffMime(Buffer.from([137,80,78,71,13,10,26,10]),'image/jpeg'),'image/png');
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

