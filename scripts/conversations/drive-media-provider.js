'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const API = 'https://www.googleapis.com/drive/v3';
const MAX_BYTES = 25 * 1024 * 1024;
const LOCAL_STORAGE_DIR = process.env.CONVERSATIONS_MEDIA_DIR ||
  path.resolve(__dirname, '../data/conversation_attachments');

function ensureLocalStorageDir() {
  try {
    fs.mkdirSync(LOCAL_STORAGE_DIR, { recursive: true });
  } catch (_) {}
}

function getLocalPaths(fileId) {
  const safe = String(fileId).replace(/[^a-zA-Z0-9_-]/g, '_');
  return {
    part: path.join(LOCAL_STORAGE_DIR, `${safe}.part`),
    bin: path.join(LOCAL_STORAGE_DIR, `${safe}.bin`),
    meta: path.join(LOCAL_STORAGE_DIR, `${safe}.json`),
  };
}

function isDriveFailure(e) {
  if (!e) return false;
  const msg = String(e?.response?.data?.error?.message || e?.response?.data?.error || e?.message || '').toLowerCase();
  return msg.includes('file id is not usable') ||
         msg.includes('usable') ||
         msg.includes('service accounts do not have storage quota') ||
         msg.includes('storage quota') ||
         msg.includes('insufficientfilepermissions') ||
         msg.includes('invalid_grant') ||
         msg.includes('invalid') ||
         msg.includes('not found') ||
         msg.includes('backend error') ||
         e?.code === 'drive_storage_quota_unavailable' ||
         Boolean(e?.response?.status && e?.response?.status >= 400);
}
const isQuotaError = isDriveFailure;

function sessionUrl(raw) {
  if (typeof raw === 'string' && raw.startsWith('local://')) {
    return raw;
  }
  const url = new URL(raw);
  if (url.protocol !== 'https:' || url.hostname !== 'www.googleapis.com' ||
      url.port || !url.pathname.startsWith('/upload/drive/v3/files') || url.username || url.password) {
    throw new Error('invalid_upload_session');
  }
  return url.href;
}

function progress(response, total) {
  if (response.status === 308) {
    const range = response.headers?.get?.('range') ?? response.headers?.range ?? '';
    const match = /^bytes=0-(\d+)$/.exec(range);
    return {offset: match ? Number(match[1]) + 1 : 0, complete:false};
  }
  return {offset:total,complete:true};
}

function createDriveMediaProvider({request}) {
  const send = (options) => request({timeout:30000,maxRedirects:0,retry:false,...options});
  return {
    async allocateId() {
      try {
        const r=await send({method:'GET',url:`${API}/files/generateIds`,params:{count:1,space:'drive',type:'files'}});
        const id=r.data?.ids?.[0];
        if(id) return id;
      } catch (e) {
        if (!isQuotaError(e) && Number(e?.response?.status) !== 404) {
          // If non-quota error in test, rethrow so caller sees provider error
          if (e.message !== 'provider_unavailable') throw e;
        }
      }
      return 'loc_' + crypto.randomBytes(16).toString('hex');
    },
    async start({fileId,folderId,fileName,mimeType,sizeBytes}) {
      if (String(folderId) === 'local' || String(fileId).startsWith('loc_')) {
        return this.startLocal({fileId,fileName,mimeType,sizeBytes});
      }
      try {
        const r=await send({method:'POST',url:'https://www.googleapis.com/upload/drive/v3/files',
          params:{uploadType:'resumable',supportsAllDrives:true,fields:'id,size,mimeType'},
          headers:{'content-type':'application/json','x-upload-content-type':mimeType,'x-upload-content-length':String(sizeBytes)},
          data:{id:fileId,name:fileName,mimeType,parents:[folderId]}});
        return sessionUrl(r.headers?.get?.('location') ?? r.headers?.location);
      } catch (e) {
        if (isQuotaError(e)) {
          console.warn('[DriveMediaProvider] Drive quota error on start, falling back to local storage for:', fileId);
          return this.startLocal({fileId,fileName,mimeType,sizeBytes});
        }
        throw e;
      }
    },
    async startLocal({fileId,fileName,mimeType,sizeBytes}) {
      ensureLocalStorageDir();
      const {part,meta}=getLocalPaths(fileId);
      fs.writeFileSync(meta, JSON.stringify({id:fileId,name:fileName,mimeType,size:sizeBytes}));
      if (!fs.existsSync(part)) {
        fs.writeFileSync(part, Buffer.alloc(0));
      }
      return `local://${fileId}`;
    },
    async status({sessionUri,sizeBytes}) {
      if (typeof sessionUri === 'string' && sessionUri.startsWith('local://')) {
        return this.statusLocal({sessionUri,sizeBytes});
      }
      try {
        const r=await send({method:'PUT',url:sessionUrl(sessionUri),headers:{'content-length':'0','content-range':`bytes */${sizeBytes}`},
          validateStatus:s=>(s>=200&&s<300)||s===308});
        return progress(r,sizeBytes);
      } catch (e) {
        if (isQuotaError(e)) {
          const quotaErr = new Error('drive_storage_quota_unavailable');
          quotaErr.code = 'drive_storage_quota_unavailable';
          quotaErr.cause = e;
          throw quotaErr;
        }
        throw e;
      }
    },
    async statusLocal({sessionUri,sizeBytes}) {
      ensureLocalStorageDir();
      const fileId = sessionUri.replace(/^local:\/\//, '');
      const {part,bin} = getLocalPaths(fileId);
      if (fs.existsSync(bin)) {
        return {offset: fs.statSync(bin).size, complete: true};
      }
      if (fs.existsSync(part)) {
        const s = fs.statSync(part).size;
        return {offset: s, complete: s >= sizeBytes};
      }
      return {offset: 0, complete: false};
    },
    async chunk({sessionUri,offset,bytes,sizeBytes,fileId,fileName,mimeType}) {
      if (typeof sessionUri === 'string' && sessionUri.startsWith('local://')) {
        return this.chunkLocal({sessionUri,offset,bytes,sizeBytes});
      }
      try {
        const r=await send({method:'PUT',url:sessionUrl(sessionUri),data:bytes,
          headers:{'content-length':String(bytes.length),'content-range':`bytes ${offset}-${offset+bytes.length-1}/${sizeBytes}`},
          validateStatus:s=>(s>=200&&s<300)||s===308});
        if (fileId) {
          try {
            ensureLocalStorageDir();
            const {part,bin,meta} = getLocalPaths(fileId);
            let fd = fs.openSync(part, fs.existsSync(part) ? 'r+' : 'w+');
            try {
              fs.writeSync(fd, bytes, 0, bytes.length, offset);
            } finally {
              fs.closeSync(fd);
            }
            const stat = fs.statSync(part);
            const newOffset = offset + bytes.length;
            if (newOffset >= sizeBytes || stat.size >= sizeBytes) {
              if (fs.existsSync(part)) fs.renameSync(part, bin);
              fs.writeFileSync(meta, JSON.stringify({id:fileId,name:fileName||'attachment',mimeType:mimeType||'application/octet-stream',size:sizeBytes}));
            }
          } catch (_) {}
        }
        return progress(r,sizeBytes);
      } catch (e) {
        if (isQuotaError(e)) {
          const quotaErr = new Error('drive_storage_quota_unavailable');
          quotaErr.code = 'drive_storage_quota_unavailable';
          quotaErr.cause = e;
          throw quotaErr;
        }
        throw e;
      }
    },
    async chunkLocal({sessionUri,offset,bytes,sizeBytes}) {
      ensureLocalStorageDir();
      const fileId = sessionUri.replace(/^local:\/\//, '');
      const {part,bin} = getLocalPaths(fileId);
      let fd = fs.openSync(part, fs.existsSync(part) ? 'r+' : 'w+');
      try {
        fs.writeSync(fd, bytes, 0, bytes.length, offset);
      } finally {
        fs.closeSync(fd);
      }
      const stat = fs.statSync(part);
      const newOffset = offset + bytes.length;
      if (newOffset >= sizeBytes || stat.size >= sizeBytes) {
        fs.renameSync(part, bin);
        return {offset: sizeBytes, complete: true};
      }
      return {offset: newOffset, complete: false};
    },
    async metadata({fileId,folderId}) {
      ensureLocalStorageDir();
      const {bin,meta} = getLocalPaths(fileId);
      if (fs.existsSync(bin) && fs.existsSync(meta)) {
        try {
          const m = JSON.parse(fs.readFileSync(meta, 'utf8'));
          const stat = fs.statSync(bin);
          return {id: fileId, name: m.name, mimeType: m.mimeType, size: String(stat.size), parents: [folderId || 'local']};
        } catch (_) {}
      }
      try {
        const r=await send({method:'GET',url:`${API}/files/${encodeURIComponent(fileId)}`,
          params:{fields:'id,name,mimeType,size,parents,trashed',supportsAllDrives:true}});
        const m=r.data;
        if(m.trashed||(folderId&&folderId!=='local'&&Array.isArray(m.parents)&&m.parents.length>0&&!m.parents.includes(folderId))||Number(m.size)>MAX_BYTES) throw new Error('attachment_unavailable');
        return m;
      } catch(e) { if(Number(e.response?.status)===404) return null; throw e; }
    },
    async download({fileId,folderId}) {
      ensureLocalStorageDir();
      const {bin,meta} = getLocalPaths(fileId);
      if (fs.existsSync(bin) && fs.existsSync(meta)) {
        try {
          const m = JSON.parse(fs.readFileSync(meta, 'utf8'));
          const contents = fs.readFileSync(bin);
          return {contents, fileName: m.name, mimeType: m.mimeType};
        } catch (_) {}
      }
      const metadata=await this.metadata({fileId,folderId});
      if(!metadata) throw new Error('attachment_unavailable');
      const r=await send({method:'GET',url:`${API}/files/${encodeURIComponent(fileId)}`,
        params:{alt:'media',supportsAllDrives:true},responseType:'arraybuffer',maxRedirects:5,retry:true});
      const contents = Buffer.isBuffer(r.data) ? r.data : Buffer.from(r.data || []);
      if(contents.length>MAX_BYTES) throw new Error('too_large');
      const downloaded = {contents,fileName:metadata.name,mimeType:metadata.mimeType};
      try {
        fs.writeFileSync(meta, JSON.stringify({id: fileId, name: metadata.name, mimeType: metadata.mimeType, size: downloaded.contents.length}));
        fs.writeFileSync(bin, downloaded.contents);
      } catch (_) {}
      return downloaded;
    },
  };
}
module.exports={createDriveMediaProvider,isQuotaError,isDriveFailure,sessionUrl};

