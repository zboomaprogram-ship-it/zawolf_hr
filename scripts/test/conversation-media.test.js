'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeUpload, validateChunk, sniffMime, validateVoiceMime } = require('../conversations/uploads');
const { createDriveMediaProvider } = require('../conversations/drive-media-provider');
const { createFirebaseStorageMediaProvider } = require('../conversations/firebase-storage-media-provider');
const { createHybridMediaProvider } = require('../conversations/hybrid-media-provider');
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

test('Firebase Storage provider resumes chunks and returns playable voice metadata', async () => {
  const objects = new Map();
  class FakeFile {
    constructor(name) { this.name=name; }
    async exists() { return [objects.has(this.name)]; }
    async save(bytes, options) { objects.set(this.name,{bytes:Buffer.from(bytes),metadata:options.metadata}); }
    async getMetadata() {
      const value=objects.get(this.name);
      if(!value) { const error=new Error('missing');error.code=404;throw error; }
      return [{size:String(value.bytes.length),...value.metadata}];
    }
    async setMetadata(metadata) { objects.get(this.name).metadata=metadata; }
    async download() { return [objects.get(this.name).bytes]; }
    async delete() { objects.delete(this.name); }
  }
  const bucket={
    file:name=>new FakeFile(name),
    async getFiles({prefix}) { return [[...objects.keys()].filter(name=>name.startsWith(prefix)).map(name=>new FakeFile(name))]; },
    async combine(sources,destination) {
      objects.set(destination.name,{bytes:Buffer.concat(sources.map(source=>objects.get(source.name).bytes)),metadata:{}});
    },
  };
  const provider=createFirebaseStorageMediaProvider({bucket});
  const fileId=await provider.allocateId();
  const session=await provider.start({fileId,folderId:provider.containerId,fileName:'voice.wav',mimeType:'audio/wav',sizeBytes:8});
  assert.deepEqual(await provider.chunk({sessionUri:session,offset:0,bytes:Buffer.from('1234'),sizeBytes:8}),{offset:4,complete:false});
  assert.deepEqual(await provider.status({sessionUri:session,sizeBytes:8}),{offset:4,complete:false});
  assert.deepEqual(await provider.chunk({sessionUri:session,offset:4,bytes:Buffer.from('5678'),sizeBytes:8}),{offset:8,complete:true});
  const metadata=await provider.metadata({fileId,folderId:provider.containerId});
  assert.equal(metadata.mimeType,'audio/wav');
  assert.equal(metadata.name,'voice.wav');
  assert.equal((await provider.download({fileId,folderId:provider.containerId})).contents.toString(),'12345678');
});

test('hybrid media provider keeps legacy Drive attachments readable', async () => {
  const calls=[];
  const primary={name:'firebase_storage',containerId:'gcs',allocateId:async()=> 'gcs_new',start:async()=>{},status:async()=>{},chunk:async()=>{},metadata:async()=>{calls.push('gcs');},download:async()=>{calls.push('gcs');}};
  const legacy={name:'google_workspace',start:async()=>{},status:async()=>{},chunk:async()=>{},metadata:async()=>{calls.push('drive');},download:async()=>{calls.push('drive');}};
  const provider=createHybridMediaProvider({primary,legacy});
  await provider.metadata({fileId:'old-drive-id'});
  await provider.download({fileId:'gcs_123'});
  assert.deepEqual(calls,['drive','gcs']);
});
