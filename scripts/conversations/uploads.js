'use strict';
const crypto=require('node:crypto');
const {safeId}=require('../conversation-operations');
const MAX_BYTES=25*1024*1024, CHUNK_BYTES=1024*1024;
function failure(code,status=400) { const e=new Error(code); e.code=code;e.status=status; return e; }
function normalizeUpload(p={}) {
  const operationId=safeId(p.operationId);
  const fileName=String(p.fileName||'').trim();
  const mimeType=String(p.mimeType||'').trim().toLowerCase();
  const sizeBytes=Number(p.sizeBytes);
  if(!operationId||!fileName||fileName.length>160||/[\\/\x00-\x1f]/.test(fileName)||
    !/^[a-z0-9.+-]+\/[a-z0-9.+-]+$/.test(mimeType)||
    !Number.isSafeInteger(sizeBytes)||sizeBytes<1||sizeBytes>MAX_BYTES) throw failure('validation_failed');
  if(p.kind==='voice' && (!Number.isFinite(p.durationSeconds)||p.durationSeconds<=0||p.durationSeconds>300)) throw failure('validation_failed');
  return {operationId,fileName,mimeType,sizeBytes,kind:p.kind==='voice'?'voice':null,durationSeconds:p.kind==='voice'?p.durationSeconds:null};
}
function validateChunk(offset,length,total) {
  if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(length)||length<1||length>CHUNK_BYTES||offset+length>total||
    (offset+length<total && length% (256*1024)!==0)) throw failure('invalid_chunk');
}
function sniffMime(b,claimed) {
  if(b.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return 'image/png';
  if(b[0]===255&&b[1]===216&&b[2]===255) return 'image/jpeg';
  if(/^GIF8[79]a/.test(b.toString('ascii',0,6))) return 'image/gif';
  if(b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WEBP') return 'image/webp';
  if(b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WAVE') return 'audio/wav';
  if(b.toString('ascii',0,5)==='%PDF-') return 'application/pdf';
  if(b.toString('ascii',4,8)==='ftyp') return claimed.startsWith('audio/')?'audio/mp4':'video/mp4';
  if(b.toString('ascii',0,3)==='ID3'||(b[0]===255&&(b[1]&224)===224)) return 'audio/mpeg';
  if(b[0]===0x1a&&b[1]===0x45&&b[2]===0xdf&&b[3]===0xa3) return claimed==='audio/webm'?'audio/webm':'video/webm';
  if(b.toString('ascii',0,4)==='OggS') return 'audio/ogg';
  if(claimed==='text/plain'&&!b.includes(0)) return 'text/plain';
  if(b[0]===80&&b[1]===75) return /^application\/(vnd\.openxmlformats-officedocument\.|zip)/.test(claimed)?claimed:'application/zip';
  return 'application/octet-stream';
}
function descriptor(id,d) {
  const mime=d.validatedMimeType||d.mimeType||'application/octet-stream';
  return {resourceId:id,fileName:d.fileName||d.name||'download',mimeType:mime,sizeBytes:d.sizeBytes||0,
    kind:d.kind==='voice'?'voice':mime.startsWith('image/')?'image':mime.startsWith('video/')?'video':mime.startsWith('audio/')?'audio':mime==='application/pdf'?'pdf':mime==='text/plain'?'text':'file',
    durationSeconds:d.durationSeconds||null,status:d.status};
}
async function readBytes(req) {
  const list=[];let size=0;
  for await(const piece of req) {size+=piece.length;if(size>CHUNK_BYTES) throw failure('too_large',413);list.push(piece);}
  return Buffer.concat(list);
}
// Firestore lease prevents two workers from concurrently mutating a Drive session.
async function leased(db,ref,body) {
  const owner=crypto.randomUUID();
  await db.runTransaction(async t=>{
    const d=(await t.get(ref)).data();
    if(!d) throw failure('not_found',404);
    if(d.leaseUntil>Date.now()) throw failure('upload_busy',409);
    t.update(ref,{leaseOwner:owner,leaseUntil:Date.now()+120000});
  });
  try {return await body();} finally {
    await db.runTransaction(async t=>{
      const d=(await t.get(ref)).data();
      if(d?.leaseOwner===owner)t.update(ref,{leaseOwner:null,leaseUntil:0});
    });
  }
}
async function handleMedia({req,res,db,actor,channel,parts,payload,sendJson,provider,ensureFolder}) {
  if(!['uploads','attachments'].includes(parts[0])) return false;
  const uploads=parts[0]==='uploads';
  if(uploads&&!channel.canPost) throw failure('access_denied',403);
  if(uploads&&req.method==='POST'&&parts.length===1) {
    const input=normalizeUpload(payload);
    const resourceId='chat:'+crypto.createHash('sha256').update(`${channel.id}:${actor.uid}:${input.operationId}`).digest('hex').slice(0,48);
    const ref=db.collection('conversationAttachments').doc(resourceId);
    await db.runTransaction(async t=>{
      const old=await t.get(ref);
      if(old.exists) {
        const d=old.data();
        if(d.sizeBytes!==input.sizeBytes||d.fileName!==input.fileName||d.mimeType!==input.mimeType) throw failure('operation_conflict',409);
      }else t.create(ref,{...input,conversationId:channel.id,uploaderUserId:actor.uid,status:'pending',offset:0,createdAt:new Date()});
    });
    const d=(await ref.get()).data();
    sendJson(res,200,{ok:true,resourceId,offset:d.offset,status:d.status});return true;
  }
  const resourceId=safeId(parts[1]);
  if(!resourceId) throw failure('validation_failed');
  const ref=db.collection('conversationAttachments').doc(resourceId);
  let d=(await ref.get()).data();
  if(!d||d.conversationId!==channel.id) throw failure('access_denied',403);
  if(uploads&&d.uploaderUserId!==actor.uid) throw failure('access_denied',403);
  const secretRef=db.collection('workspaceResourceSecrets').doc(resourceId);
  if(!uploads) {
    if(d.status!=='uploaded') throw failure('attachment_unavailable',409);
    if(req.method!=='GET')throw failure('not_found',404);
    if(parts.length===2)sendJson(res,200,{ok:true,attachment:descriptor(resourceId,d)});
    else if(parts.length===3&&parts[2]==='download') {
      const secret=(await secretRef.get()).data();
      if(!secret)throw failure('attachment_unavailable',404);
      const file=await provider.download({fileId:secret.externalId,folderId:secret.parentExternalId});
      await db.collection('conversationAudit').doc(crypto.randomUUID()).set({actorId:actor.uid,conversationId:channel.id,resourceId,action:'attachment_download',createdAt:new Date()});
      res.writeHead(200,{'content-type':d.validatedMimeType||file.mimeType,'content-length':String(file.contents.length),
        'content-disposition':`attachment; filename*=UTF-8''${encodeURIComponent(d.fileName||d.name||file.fileName)}`,
        'cache-control':'private, no-store','x-content-type-options':'nosniff'});res.end(file.contents);
    }else throw failure('not_found',404);
    return true;
  }
  await leased(db,ref,async()=>{
    d=(await ref.get()).data();
    if(d.status==='uploaded') {
      sendJson(res,200,{ok:true,resourceId,offset:d.sizeBytes,status:'uploaded',attachment:descriptor(resourceId,d)});return;
    }
    let secret=(await secretRef.get()).data();
    if(!secret) {
      const folderId=await ensureFolder();
      if(!folderId)throw failure('drive_upload_not_ready',503);
      const fileId=await provider.allocateId();
      secret={externalId:fileId,parentExternalId:folderId,provider:'google_workspace'};
      await secretRef.set(secret);
    }
    // Resolve provider-success / response-loss before creating any new session.
    const finished=await provider.metadata({fileId:secret.externalId,folderId:secret.parentExternalId});
    if(finished) {
      if(Number(finished.size)!==d.sizeBytes)throw failure('upload_size_mismatch',409);
      await ref.update({status:'uploaded',offset:d.sizeBytes});d={...d,status:'uploaded',offset:d.sizeBytes};
    }else {
      let offset=d.offset||0;
      if(secret.sessionUri) {
        try {offset=(await provider.status({sessionUri:secret.sessionUri,sizeBytes:d.sizeBytes})).offset;}
        catch(e) {if([404,410].includes(Number(e.response?.status))){secret.sessionUri=null;offset=0;}else throw e;}
      }
      if(!secret.sessionUri) {
        secret.sessionUri=await provider.start({fileId:secret.externalId,folderId:secret.parentExternalId,...d});
        await secretRef.set(secret);offset=0;
      }
      if(req.method==='PUT'&&parts.length===2) {
        const requested=Number(req.headers['x-upload-offset']);
        const bytes=await readBytes(req);
        validateChunk(requested,bytes.length,d.sizeBytes);
        if(requested!==offset) {await ref.update({offset});sendJson(res,409,{ok:false,code:'upload_offset_mismatch',offset});return;}
        if(offset===0) {
          const validatedMimeType=sniffMime(bytes,d.mimeType);
          if(d.kind==='voice'&&validatedMimeType!=='audio/wav')throw failure('invalid_voice');
          d={...d,validatedMimeType};await ref.update({validatedMimeType});
        }
        const state=await provider.chunk({sessionUri:secret.sessionUri,offset,bytes,sizeBytes:d.sizeBytes});
        offset=state.offset;
        if(state.complete) {
          const m=await provider.metadata({fileId:secret.externalId,folderId:secret.parentExternalId});
          if(!m||Number(m.size)!==d.sizeBytes)throw failure('upload_size_mismatch',409);
          d={...d,status:'uploaded'};
        }
      }else if(!(req.method==='GET'&&parts.length===2)&&!(req.method==='POST'&&parts[2]==='finalize'))throw failure('not_found',404);
      d={...d,offset};await ref.update({offset,status:d.status});
    }
    if(parts[2]==='finalize'&&d.status!=='uploaded')throw failure('upload_incomplete',409);
    sendJson(res,200,{ok:true,resourceId,offset:d.offset,status:d.status,attachment:descriptor(resourceId,d)});
  });
  return true;
}
module.exports={handleMedia,normalizeUpload,validateChunk,sniffMime,descriptor};
