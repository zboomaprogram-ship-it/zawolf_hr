'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { firestore } = require('./fixtures/chat-firestore');
const { sendMessage, messageAction, presence } = require('../conversations/messages');
const { createRequest, reviewRequest, updateMembers } = require('../conversations/requests');
const Q = require('../conversations/queries');
const C = require('../conversations/common');
const { publicIPv4, fetchPreview } = require('../conversations/previews');
const actor = { uid: 'alice', role: 'employee', displayName: 'أليس' };
const hr = { uid: 'hr', role: 'hr_manager' };
const now = new Date('2026-09-06T10:00:00Z');
function seed(extra = {}) { return firestore({ 'conversations/room': { kind: 'custom', approved: true, state: 'active', name: 'الفريق', memberUserIds: ['alice','bob'], revision: 1 }, 'users/alice': { isActive: true }, 'users/bob': { isActive: true }, 'users/hr': { isActive: true, role: 'hr_manager' }, ...extra }); }
const send = (db, payload = {operationId:'send',body:'hello'}) => sendMessage({ db, actor, channelId:'room', payload, now });
const code = expected => error => error.code === expected;
test('concurrent send and lost-response replay create one message/change/audit/notification', async () => {
  const db = seed(); const results = await Promise.all([send(db),send(db)]);
  assert.deepEqual(results[0],results[1]);
  const keys=Object.keys(db.dump());
  for (const prefix of ['conversations/room/messages/','conversations/room/changes/','conversationAudit/','notifications/bob/items/']) assert.equal(keys.filter(k=>k.startsWith(prefix)).length,1);
  await assert.rejects(send(db,{operationId:'send',body:'changed'}),code('operation_conflict'));
});
test('attachment-only legacy send enters v2 change feed without synthetic text', async () => {
  const db=seed({'conversationAttachments/photo':{conversationId:'room',status:'uploaded',name:'صورة.png',mimeType:'image/png',sizeBytes:20}});
  const result=await sendMessage({db,actor,channelId:'room',payload:{operationId:'legacy',body:'',attachmentResourceIds:['photo']},legacy:true,now});
  assert.equal(result.message.id,'legacy'); assert.equal(result.message.body,'');
  const channel=await C.channelFor(db,actor,'room');
  const changes=await Q.changes({db,channel,params:new URLSearchParams('after=0')});
  assert.equal(changes.messages[0].attachments[0].fileName,'صورة.png'); assert.equal(changes.changeCursor,'1');
});
test('HR nonmember may read approved custom history but cannot send/react/read/typing', async () => {
  const db=seed(); const message=(await send(db)).message;
  assert.equal((await C.channelFor(db,hr,'room')).canPost,false);
  await assert.rejects(sendMessage({db,actor:hr,channelId:'room',payload:{operationId:'hr-send',body:'no'},now}),code('access_denied'));
  await assert.rejects(messageAction({db,actor:hr,channelId:'room',messageId:message.id,payload:{operationId:'hr-react',action:'react',emoji:'👍'},now}),code('access_denied'));
  await assert.rejects(presence({db,actor:hr,channelId:'room',payload:{operationId:'hr-read',messageId:message.id},now}),code('access_denied'));
  await assert.rejects(presence({db,actor:hr,channelId:'room',typing:true,payload:{operationId:'hr-type',typing:true},now}),code('access_denied'));
  assert.equal(C.access(hr,{kind:'custom',memberUserIds:[]}).canRead,false);
  assert.equal(C.access(hr,{kind:'manager_channel',memberUserIds:[]}).canRead,false);
});
test('edit/delete enforce ownership, revision and exact fifteen-minute boundary with audit tombstone', async()=>{
  const db=seed(); const m=(await send(db)).message;
  const args={db,actor,channelId:'room',messageId:m.id};
  await assert.rejects(messageAction({...args,actor:{uid:'bob'},payload:{operationId:'not-owner',action:'delete',expectedRevision:1},now}),code('access_denied'));
  const edited=await messageAction({...args,payload:{operationId:'edit',action:'edit',expectedRevision:1,body:'new'},now:new Date(now.getTime()+900000)});
  assert.equal(edited.message.revision,2);
  await assert.rejects(messageAction({...args,payload:{operationId:'stale',action:'delete',expectedRevision:1},now}),code('revision_conflict'));
  await assert.rejects(messageAction({...args,payload:{operationId:'late',action:'delete',expectedRevision:2},now:new Date(now.getTime()+900001)}),code('edit_window_expired'));
  const deleted=await messageAction({...args,payload:{operationId:'delete',action:'delete',expectedRevision:2},now});
  assert.equal(deleted.message.state,'deleted'); assert.equal(deleted.message.body,'');
  assert.ok(Object.values(db.dump()).some(d=>d.action==='delete'&&d.previous?.body==='new'));
});
test('reaction retries do not toggle twice; a distinct operation toggles off', async()=>{
  const db=seed(),m=(await send(db)).message;
  const args={db,actor,channelId:'room',messageId:m.id,now,payload:{operationId:'react',action:'react',emoji:'👍'}};
  await messageAction(args); await messageAction(args);
  assert.equal(db.dump()[`conversations/room/messages/${m.id}`].reactions.alice,'👍');
  await messageAction({...args,payload:{...args.payload,operationId:'react-again'}});
  assert.deepEqual(db.dump()[`conversations/room/messages/${m.id}`].reactions,{});
});
test('forward checks both channels and creates destination-bound private references',async()=>{
  const db=seed({'conversations/destination':{state:'active',memberUserIds:['alice','bob']},'conversationAttachments/file':{conversationId:'room',status:'uploaded',fileName:'secret.pdf',externalFileId:'private-provider-id',mimeType:'application/pdf'}});
  const m=(await send(db,{operationId:'attachment',body:'',attachmentResourceIds:['file']})).message;
  const args={db,actor,channelId:'room',messageId:m.id,now,payload:{operationId:'forward',action:'forward',destinationId:'destination'}};
  const forwarded=(await messageAction(args)).message;
  assert.notEqual(forwarded.attachmentResourceIds[0],'file');
  assert.equal(db.dump()[`conversationAttachments/${forwarded.attachmentResourceIds[0]}`].conversationId,'destination');
  assert.equal(JSON.stringify(forwarded).includes('private-provider-id'),false);
  await assert.rejects(messageAction({...args,payload:{...args.payload,operationId:'denied',destinationId:'unknown'}}),code('access_denied'));
});
test('read positions never regress and typing false clears current actor',async()=>{
  const db=seed();const a=(await send(db)).message;
  const b=(await sendMessage({db,actor,channelId:'room',payload:{operationId:'second',body:'second'},now:new Date(now.getTime()+1000)})).message;
  for(const [operationId,messageId] of [['read-b',b.id],['read-a',a.id]]) await presence({db,actor,channelId:'room',payload:{operationId,messageId},now});
  assert.equal(db.dump()['conversations/room'].readers.alice.messageId,b.id);
  await presence({db,actor,channelId:'room',typing:true,payload:{operationId:'type-on',typing:true},now});
  await presence({db,actor,channelId:'room',typing:true,payload:{operationId:'type-off',typing:false},now});
  assert.deepEqual(db.dump()['conversations/room'].typing,{});
});
test('concurrent review decisions create exactly one channel and replay the winner',async()=>{
  const db=seed(); const request=(await createRequest({db,actor,payload:{operationId:'request',name:'فريق',reason:'عمل',memberUserIds:['bob']},now})).request;
  const args={db,actor:hr,requestId:request.id,now,payload:{operationId:'approve',decision:'approved',expectedRevision:1}};
  const results=await Promise.allSettled([reviewRequest(args),reviewRequest({...args,payload:{operationId:'reject',decision:'rejected',reason:'لا',expectedRevision:1}})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results[1].reason.code,'revision_conflict');
  assert.equal(Object.values(db.dump()).filter(d=>d.requestId===request.id&&d.kind==='custom').length,1);
  assert.deepEqual(await reviewRequest(args),results[0].value);
});
test('removal revokes cached-channel authorization and all transactional mutations',async()=>{
  const db=seed({'users/charlie':{isActive:true}});
  await updateMembers({db,actor:hr,channelId:'room',payload:{operationId:'members',expectedRevision:1,memberUserIds:['bob','charlie']},now});
  await assert.rejects(send(db),code('access_denied'));
  await assert.rejects(C.channelFor(db,actor,'room'),code('access_denied'));
});
test('search/history/change reads are bounded and history paginates equal timestamps',async()=>{
  const db=seed();for(let i=0;i<3;i++)await send(db,{operationId:`send-${i}`,body:`message ${i}`});
  const channel=await C.channelFor(db,actor,'room');
  const first=await Q.history({db,channel,params:new URLSearchParams('limit=2')});
  const second=await Q.history({db,channel,params:new URLSearchParams({limit:'2',before:first.nextCursor})});
  assert.equal(new Set([...first.messages,...second.messages].map(m=>m.id)).size,3);
  await Q.search({db,channel,params:new URLSearchParams('q=message')});
  assert.ok(db.reads.filter(r=>typeof r==='object').every(r=>r.limit<=200));
});
test('preview rejects private/reserved addresses and redirect overflow',async()=>{
  for(const ip of ['127.0.0.1','10.0.0.2','169.254.169.254','192.168.1.1','100.64.0.1','::1','198.18.0.1'])assert.equal(publicIPv4(ip),false);
  assert.equal(publicIPv4('8.8.8.8'),true);
  await assert.rejects(fetchPreview('http://user:password@example.org'),code('preview_unavailable'));
  await assert.rejects(fetchPreview('https://redirect.example',{request:async()=>({location:'/again'})}),code('preview_unavailable'));
});
test('inbox unread aggregate excludes own messages and respects equal-time read positions',async()=>{
  const db=seed({
    'conversations/room/messages/a':{senderUserId:'bob',sentAt:now},
    'conversations/room/messages/b':{senderUserId:'bob',sentAt:now},
    'conversations/room/messages/c':{senderUserId:'alice',sentAt:now},
  });
  await presence({db,actor,channelId:'room',payload:{operationId:'read-first',messageId:'a'},now});
  const inbox=await Q.channels({db,actor,params:new URLSearchParams()});
  assert.equal(inbox.channels[0].unreadCount,1);
  assert.ok(db.reads.filter(r=>typeof r==='object').every(r=>r.limit<=100));
});
test('rich-chat capability requires explicit actor rollout and authenticated router',async()=>{
  const {isPhase007FlagEnabled}=require('../feature-flags');
  assert.equal(isPhase007FlagEnabled('conversations_rich_chat_v1',{},'alice'),false);
  const config={conversations_rich_chat_v1:{enabled:true,actorIds:['alice']}};
  assert.equal(isPhase007FlagEnabled('conversations_rich_chat_v1',config,'alice'),true);
  assert.equal(isPhase007FlagEnabled('conversations_rich_chat_v1',config,'bob'),false);
  const {handleRichConversationRequest}=require('../conversations/router');
  let response;
  const args={req:{method:'GET'},res:{},url:new URL('https://example.org/conversations/v2/capabilities'),db:seed(),actor:hr,enabled:false,sendJson:(_res,status,data)=>{response={status,data};}};
  await handleRichConversationRequest(args);assert.deepEqual(response,{status:200,data:{ok:true,enabled:false,canReview:true}});
  await handleRichConversationRequest({...args,actor:null});assert.equal(response.status,401);
  await handleRichConversationRequest({...args,url:new URL('https://example.org/conversations/v2/channels')});assert.equal(response.data.code,'feature_disabled');
});
