'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { firestore } = require('./fixtures/chat-firestore');
const { sendMessage, messageAction, presence } = require('../conversations/messages');
const { createRequest, reviewRequest, updateMembers } = require('../conversations/requests');
const Q = require('../conversations/queries');
const C = require('../conversations/common');
const P = require('../conversations/direct-policy');
const { createDirect } = require('../conversations/direct');
const { publicIPv4, fetchPreview } = require('../conversations/previews');
const actor = { uid: 'alice', role: 'employee', displayName: 'أليس' };
const hr = { uid: 'hr', role: 'hr_manager' };
const now = new Date('2026-09-06T10:00:00Z');
function seed(extra = {}) { return firestore({ 'conversations/room': { kind: 'custom', approved: true, state: 'active', name: 'الفريق', memberUserIds: ['alice','bob'], revision: 1, updatedAt: new Date('2026-09-06T10:00:00Z'), latestActivityAt: new Date('2026-09-06T10:00:00Z'), latestActivityId: 'room' }, 'users/alice': { isActive: true }, 'users/bob': { isActive: true }, 'users/hr': { isActive: true, role: 'hr_manager' }, ...extra }); }
const send = (db, payload = {operationId:'send',body:'hello'}) => sendMessage({ db, actor, channelId:'room', payload, now });
const code = expected => error => error.code === expected;
test('concurrent send and lost-response replay create one message/change/audit/notification', async () => {
  const db = seed(); const results = await Promise.all([send(db),send(db)]);
  assert.deepEqual(results[0],results[1]);
  const keys=Object.keys(db.dump());
  for (const prefix of ['conversations/room/messages/','conversations/room/changes/','conversationAudit/','notifications/bob/items/']) assert.equal(keys.filter(k=>k.startsWith(prefix)).length,1);
  const notification = Object.entries(db.dump()).find(([key]) => key.startsWith('notifications/bob/items/'))?.[1];
  assert.equal(notification.data.route, `/conversations/channel/${encodeURIComponent('room')}`);
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
test('HR/admin can participate in approved custom groups without becoming listed members', async () => {
  const db=seed(); const message=(await send(db)).message;
  assert.equal((await C.channelFor(db,hr,'room')).canPost,true);
  const hrMessage=await sendMessage({db,actor:hr,channelId:'room',payload:{operationId:'hr-send',body:'approved'},now});
  assert.equal(hrMessage.message.senderUserId,'hr');
  await messageAction({db,actor:hr,channelId:'room',messageId:message.id,payload:{operationId:'hr-react',action:'react',emoji:'👍'},now});
  await presence({db,actor:hr,channelId:'room',payload:{operationId:'hr-read',messageId:message.id},now});
  await presence({db,actor:hr,channelId:'room',typing:true,payload:{operationId:'hr-type',typing:true},now});
  assert.equal(C.access(hr,{kind:'custom',approved:true,memberUserIds:[]}).canPost,true);
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
  assert.equal(inbox.channels.find(channel => channel.id === 'room').unreadCount,1);
  assert.ok(db.reads.filter(r=>typeof r==='object').every(r=>r.limit<=100));
});
test('authorized channel members return names without exposing unrelated users', async()=>{
  const db=seed({
    'users/alice':{isActive:true,displayName:'أليس',department:'Data Analytics'},
    'users/bob':{isActive:true,name:'بوب',department:'Data Analytics'},
    'users/hidden':{isActive:true,name:'غير عضو'},
  });
  const channel=await C.channelFor(db,actor,'room');
  const page=await Q.members({db,channel});
  assert.deepEqual(page.members.map(member=>member.id).sort(),['alice','bob']);
  assert.equal(page.members.find(member=>member.id==='alice').name,'أليس');
});
test('private chat policy enforces employee, manager, HR/admin, and IT boundaries', () => {
  const employee = { uid: 'employee', role: 'employee', managerId: 'manager', department: 'Sales' };
  assert.equal(P.canDirect(employee, { id: 'peer', role: 'employee', department: 'Other' }), true);
  assert.equal(P.canDirect(employee, { id: 'manager', role: 'manager', department: 'Sales' }), true);
  assert.equal(P.canDirect(employee, { id: 'foreign-manager', role: 'manager', department: 'Other' }), false);
  assert.equal(P.canDirect(employee, { id: 'hr', role: 'hr_manager' }), true);
  assert.equal(P.canDirect(employee, { id: 'admin', role: 'super_admin' }), true);
  assert.equal(P.canDirect(employee, { id: 'it', role: 'manager', department: 'IT' }), true);
  assert.equal(P.canDirect({ uid: 'manager', role: 'manager' }, { id: 'any', role: 'manager' }), true);
  assert.equal(P.canDirect({ uid: 'admin', role: 'super_admin' }, { id: 'any', role: 'employee' }), true);
  assert.equal(P.canDirect(employee, { id: 'gone', isActive: false }), false);
});
test('direct creation is deterministic, participant-only, and rejects forged targets', async () => {
  const db = seed({
    'users/alice': { isActive: true, role: 'employee', managerId: 'manager' },
    'users/bob': { isActive: true, role: 'employee', displayName: 'بوب' },
    'users/manager': { isActive: true, role: 'manager' },
    'users/foreign': { isActive: true, role: 'manager' },
  });
  const request = { db, actor, payload: { operationId: 'direct-bob', targetUserId: 'bob' }, now };
  const [first, second] = await Promise.all([createDirect(request), createDirect(request)]);
  assert.deepEqual(first, second);
  const channel = first.channel;
  assert.equal(channel.kind, 'direct');
  assert.deepEqual(channel.participantUserIds, ['alice', 'bob']);
  assert.equal((await C.channelFor(db, { uid: 'bob' }, channel.id)).canPost, true);
  const aliceChannel = await C.channelFor(db, actor, channel.id);
  const bobChannel = await C.channelFor(db, { uid: 'bob' }, channel.id);
  assert.equal((await Q.channelSummary({ db, actor, channel: aliceChannel })).channel.name, 'بوب');
  assert.equal((await Q.channelSummary({ db, actor: { uid: 'bob' }, channel: bobChannel })).channel.name, 'alice');
  const { handleRichConversationRequest } = require('../conversations/router');
  let response;
  await handleRichConversationRequest({
    req: { method: 'GET' }, res: {},
    url: new URL(`https://example.org/conversations/v2/channels/${encodeURIComponent(channel.id)}`),
    db, actor, enabled: true,
    sendJson: (_res, status, data) => { response = { status, data }; },
  });
  assert.equal(response.status, 200);
  assert.equal(response.data.channel.name, 'بوب');
  await assert.rejects(C.channelFor(db, { uid: 'hr', role: 'hr_manager' }, channel.id), code('access_denied'));
  await assert.rejects(createDirect({ ...request, payload: { operationId: 'direct-foreign', targetUserId: 'foreign' } }), code('access_denied'));
});
test('a deactivated direct participant keeps history but disables posting', async () => {
  const db = seed({
    'users/alice': { isActive: true, role: 'employee' },
    'users/bob': { isActive: true, role: 'employee' },
  });
  const created = await createDirect({
    db, actor, payload: { operationId: 'direct-inactive', targetUserId: 'bob' }, now,
  });
  await db.collection('users').doc('bob').set({ isActive: false }, { merge: true });
  const channel = await C.channelFor(db, actor, created.channel.id);
  assert.equal(channel.canRead, true);
  assert.equal(channel.canPost, false);
  assert.equal((await Q.history({ db, channel, params: new URLSearchParams() })).canPost, false);
  assert.equal(
    (await Q.channels({ db, actor, params: new URLSearchParams('section=direct') }))
      .channels.find(item => item.id === created.channel.id).canPost,
    false,
  );
  await assert.rejects(sendMessage({
    db, actor, channelId: created.channel.id,
    payload: { operationId: 'after-deactivation', body: 'لا يجب الإرسال' }, now,
  }), code('access_denied'));
});
test('section inboxes do not mix direct and groups and newest activity is first', async () => {
  const db = seed({
    'conversations/direct:a': { kind: 'direct', state: 'active', memberUserIds: ['alice', 'bob'], participantUserIds: ['alice', 'bob'], name: 'بوب', updatedAt: new Date('2026-09-06T11:00:00Z'), latestActivityAt: new Date('2026-09-06T11:00:00Z'), latestActivityId: 'b' },
    'conversations/old': { kind: 'custom', approved: true, state: 'active', memberUserIds: ['alice', 'bob'], name: 'قديم', updatedAt: new Date('2026-09-06T09:00:00Z'), latestActivityAt: new Date('2026-09-06T09:00:00Z'), latestActivityId: 'a' },
    'conversations/new': { kind: 'custom', approved: true, state: 'active', memberUserIds: ['alice', 'bob'], name: 'جديد', updatedAt: new Date('2026-09-06T12:00:00Z'), latestActivityAt: new Date('2026-09-06T12:00:00Z'), latestActivityId: 'c' },
  });
  const direct = await Q.channels({ db, actor, params: new URLSearchParams('section=direct') });
  const groups = await Q.channels({ db, actor, params: new URLSearchParams('section=group') });
  assert.deepEqual(direct.channels.map(c => c.id), ['direct:a']);
  assert.deepEqual(groups.channels.map(c => c.id), ['company:general', 'new', 'room', 'old']);
});
test('company group is created once and permits every active employee', async () => {
  const db = seed({'users/charlie': { isActive: true }});
  await Promise.all([Q.channels({db, actor, params: new URLSearchParams('section=group')}), Q.channels({db, actor: {uid:'charlie'}, params: new URLSearchParams('section=group')})]);
  assert.equal(Object.keys(db.dump()).filter(key => key === 'conversations/company:general').length, 1);
  assert.equal((await C.channelFor(db, {uid:'charlie'}, 'company:general')).canPost, true);
});
test('company messages queue a durable fan-out instead of relying on an open client', async () => {
  const db = seed({'users/charlie': { isActive: true }});
  await Q.channels({db, actor, params: new URLSearchParams('section=group')});
  await sendMessage({db, actor, channelId:'company:general', payload:{operationId:'company-message',body:'إعلان'}, now});
  const outboxes = Object.entries(db.dump()).filter(([key]) => key.startsWith('conversationNotificationOutbox/'));
  assert.equal(outboxes.length, 1);
  assert.equal(outboxes[0][1].dispatchStatus, 'pending');
  assert.equal(Object.keys(db.dump()).some(key => key.startsWith('notifications/bob/items/')), false);
});
test('only bundled sticker identifiers can be sent and forwarded', async () => {
  const db = seed();
  const sent = await sendMessage({db, actor, channelId:'room', payload:{operationId:'sticker', body:'', stickerId:'party'}, now});
  assert.equal(sent.message.stickerId, 'party');
  await assert.rejects(sendMessage({db, actor, channelId:'room', payload:{operationId:'untrusted-sticker', body:'', stickerId:'https://example.org/sticker.gif'}, now}), code('validation_failed'));
});
test('conversation notification preferences are actor-owned and idempotent', async () => {
  const db = seed();
  const payload = {operationId:'mute-room', enabled:false};
  const result = await Q.setNotificationPreference({db, actor, channelId:'room', payload, now});
  assert.deepEqual(result, {enabled:false});
  assert.deepEqual(await Q.setNotificationPreference({db, actor, channelId:'room', payload, now}), result);
  const channel = await C.channelFor(db, actor, 'room');
  assert.deepEqual(await Q.notificationPreference({db, actor, channel}), {enabled:false});
  await assert.rejects(Q.setNotificationPreference({db, actor:{uid:'outsider'}, channelId:'room', payload:{operationId:'forged-mute',enabled:false}, now}), code('access_denied'));
});
test('a muted conversation suppresses only its device push', async () => {
  const { shouldSkipMutedConversation } = require('../dispatch-notifications');
  const db = {
    collection: () => ({
      doc: () => ({
        get: async () => ({ exists: true, data: () => ({ enabled: false }) }),
      }),
    }),
  };
  const item = {
    userId: 'bob',
    data: { type: 'conversation', data: { conversationId: 'room' } },
  };
  assert.equal(await shouldSkipMutedConversation(db, item), true);
  assert.equal(await shouldSkipMutedConversation(db, {...item, data: {type: 'leave'}}), false);
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
test('eligible-contacts and contact-departments route through router without throwing', async () => {
  const {handleRichConversationRequest} = require('../conversations/router');
  let response;
  const db = seed({
    'users/alice': { isActive: true, department: 'Data Analytics', displayName: 'أليس' },
    'users/bob': { isActive: true, department: 'Data Analytics', displayName: 'بوب' },
  });
  const sendJson = (_res, status, data) => { response = { status, data }; };
  await handleRichConversationRequest({
    req: { method: 'GET' },
    res: {},
    url: new URL('https://example.org/conversations/v2/eligible-contacts?department=Data+Analytics'),
    db,
    actor: { uid: 'alice', role: 'employee', displayName: 'أليس' },
    enabled: true,
    sendJson,
  });
  assert.equal(response.status, 200);
  assert.ok(Array.isArray(response.data.contacts));
  assert.equal(response.data.contacts.length, 1);
  assert.equal(response.data.contacts[0].id, 'bob');

  await handleRichConversationRequest({
    req: { method: 'GET' },
    res: {},
    url: new URL('https://example.org/conversations/v2/contact-departments'),
    db,
    actor: { uid: 'alice', role: 'employee', displayName: 'أليس' },
    enabled: true,
    sendJson,
  });
  assert.equal(response.status, 200);
  assert.ok(Array.isArray(response.data.departments));
  assert.equal(response.data.departments[0].name, 'Data Analytics');
});

test('posting message to direct channel with encoded colon and admin object succeeds', async () => {
  const { handleRichConversationRequest } = require('../conversations/router');
  let response;
  const db = seed({
    'conversations/direct:abc': {
      kind: 'direct',
      state: 'active',
      memberUserIds: ['alice', 'bob'],
      participantUserIds: ['alice', 'bob'],
      name: 'بوب',
      revision: 1,
      changeSequence: 0,
      updatedAt: new Date(),
      latestActivityAt: new Date(),
    },
    'users/alice': { isActive: true, displayName: 'أليس' },
    'users/bob': { isActive: true, displayName: 'بوب' },
  });
  const mockAdmin = require('firebase-admin');
  await handleRichConversationRequest({
    req: { method: 'POST' },
    res: {},
    url: new URL('https://notification.zawolf.ai/conversations/v2/channels/direct%3Aabc/messages'),
    db,
    admin: mockAdmin,
    actor: { uid: 'alice', role: 'employee', displayName: 'أليس' },
    enabled: true,
    readJsonBody: async () => ({
      operationId: 'op-direct-send',
      body: 'رسالة خاصة',
      attachmentResourceIds: [],
    }),
    sendJson: (_res, status, data) => { response = { status, data }; },
  });
  assert.equal(response.status, 200);
  assert.equal(response.data.ok, true);
  assert.equal(response.data.message.body, 'رسالة خاصة');
});

test('legacy direct channels without memberUserIds still send and notify the other participant', async () => {
  const db = seed({
    'conversations/direct:legacy': {
      kind: 'direct', state: 'active', participantUserIds: ['alice', 'bob'],
      name: 'بوب', revision: 1, changeSequence: 0, updatedAt: now,
      latestActivityAt: now,
    },
  });
  const result = await sendMessage({
    db,
    actor,
    channelId: 'direct:legacy',
    payload: { operationId: 'legacy-direct-send', body: 'رسالة', attachmentResourceIds: [] },
    now,
  });
  assert.equal(result.message.body, 'رسالة');
  assert.equal(
    Object.keys(db.dump()).filter(key => key.startsWith('notifications/bob/items/chat_')).length,
    1,
  );
});
