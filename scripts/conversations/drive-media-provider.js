'use strict';
const API = 'https://www.googleapis.com/drive/v3';
const MAX_BYTES = 25 * 1024 * 1024;
function sessionUrl(raw) {
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
      const r=await send({method:'GET',url:`${API}/files/generateIds`,params:{count:1,space:'drive',type:'files'}});
      const id=r.data?.ids?.[0];
      if(!id) throw new Error('provider_unavailable');
      return id;
    },
    async start({fileId,folderId,fileName,mimeType,sizeBytes}) {
      const r=await send({method:'POST',url:'https://www.googleapis.com/upload/drive/v3/files',
        params:{uploadType:'resumable',supportsAllDrives:true,fields:'id,size,mimeType'},
        headers:{'content-type':'application/json','x-upload-content-type':mimeType,'x-upload-content-length':String(sizeBytes)},
        data:{id:fileId,name:fileName,mimeType,parents:[folderId]}});
      return sessionUrl(r.headers?.get?.('location') ?? r.headers?.location);
    },
    async status({sessionUri,sizeBytes}) {
      const r=await send({method:'PUT',url:sessionUrl(sessionUri),headers:{'content-length':'0','content-range':`bytes */${sizeBytes}`},
        validateStatus:s=>(s>=200&&s<300)||s===308});
      return progress(r,sizeBytes);
    },
    async chunk({sessionUri,offset,bytes,sizeBytes}) {
      const r=await send({method:'PUT',url:sessionUrl(sessionUri),data:bytes,
        headers:{'content-length':String(bytes.length),'content-range':`bytes ${offset}-${offset+bytes.length-1}/${sizeBytes}`},
        validateStatus:s=>(s>=200&&s<300)||s===308});
      return progress(r,sizeBytes);
    },
    async metadata({fileId,folderId}) {
      try {
        const r=await send({method:'GET',url:`${API}/files/${encodeURIComponent(fileId)}`,
          params:{fields:'id,name,mimeType,size,parents,trashed',supportsAllDrives:true}});
        const m=r.data;
        if(m.trashed||!m.parents?.includes(folderId)||Number(m.size)>MAX_BYTES) throw new Error('attachment_unavailable');
        return m;
      } catch(e) { if(Number(e.response?.status)===404) return null; throw e; }
    },
    async download({fileId,folderId}) {
      const metadata=await this.metadata({fileId,folderId});
      if(!metadata) throw new Error('attachment_unavailable');
      const r=await send({method:'GET',url:`${API}/files/${encodeURIComponent(fileId)}`,
        params:{alt:'media',supportsAllDrives:true},responseType:'stream'});
      const chunks=[];let length=0;
      for await(const piece of r.data) {
        length+=piece.length;
        if(length>MAX_BYTES) {r.data.destroy?.();throw new Error('too_large');}
        chunks.push(piece);
      }
      return {contents:Buffer.concat(chunks),fileName:metadata.name,mimeType:metadata.mimeType};
    },
  };
}
module.exports={createDriveMediaProvider};
