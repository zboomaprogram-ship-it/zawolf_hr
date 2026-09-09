'use strict';
const { safeId } = require('../conversation-operations');
const C = require('./common');
const P = require('./direct-policy');
const { ensureGeneral } = require('./company');
const { channelDto } = require('./requests');
const pageSize = (value, max) => Math.min(max, Math.max(1, Number.parseInt(value, 10) || max));
const inboxUnreadConcurrency = 8;
function presenceDto(channel, now = new Date()) {
  return { readers: channel.data.readers || {}, typing: Object.values(channel.data.typing || {}).filter(v => Date.parse(v.expiresAt) > now.getTime()), canPost: channel.canPost };
}
function pageById(query, value, limit) {
  if (value && !safeId(value)) C.fail('invalid_cursor');
  query = query.orderBy('__name__');
  if (value) query = query.startAfter(value);
  return query.limit(limit);
}
async function unreadCount(channel, actor) {
  const read = channel.data.readers?.[actor.uid];
  try {
    const snaps = await channel.ref.collection('messages').orderBy('sentAt', 'desc').limit(100).get();
    if (read?.sentAt) {
      const at = new Date(read.sentAt).getTime();
      return snaps.docs.filter(doc => {
        const message = doc.data();
        if (message.senderUserId === actor.uid) return false;
        const messageAt = (message.sentAt?.toDate ? message.sentAt.toDate() : new Date(message.sentAt || 0)).getTime();
        return messageAt > at || (messageAt === at && doc.id > (read.messageId || ''));
      }).length;
    }
    return snaps.docs.filter(doc => doc.data().senderUserId !== actor.uid).length;
  } catch (_) {
    return 0;
  }
}
async function boundedMap(items, concurrency, callback) {
  const results = new Array(items.length);
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const index = next++;
      results[index] = await callback(items[index]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, worker));
  return results;
}
async function channels({db, actor, params}) {
  await ensureGeneral(db);
  const section = params.get('section');
  if (section && !['direct', 'group'].includes(section)) C.fail('validation_failed');
  if (section) return sectionChannels({ db, actor, params, section });
  // One bounded page across legacy and custom channels avoids an unbounded merge
  // and gives stable pagination even when authorization filters a whole page.
  const docs = await pageById(db.collection('conversations'), params.get('cursor'), 50).get();
  const accessible = docs.docs
    .map(doc => ({ id: doc.id, ref: doc.ref, data: doc.data() }))
    .filter(channel => C.access(actor, channel.data).canRead)
    .filter(channel => !section || (section === 'direct' ? channel.data.kind === 'direct' : channel.data.kind !== 'direct'));
  // Firestore child queries used to run one-by-one, making each inbox open wait
  // for every channel. Eight workers retain a fixed read/concurrency budget.
  const result = await boundedMap(accessible, inboxUnreadConcurrency, async channel =>
    channelDto(channel, actor, await unreadCount(channel, actor)));
  result.sort((a, b) => `${b.latestActivityAt || ''}`.localeCompare(`${a.latestActivityAt || ''}`) || `${b.latestActivityId || b.id}`.localeCompare(`${a.latestActivityId || a.id}`));
  return { channels: result, nextCursor: docs.size === 50 ? docs.docs.at(-1).id : null };
}
function activityPosition(value) {
  if (!value) return null;
  try {
    const decoded = JSON.parse(Buffer.from(value, 'base64url').toString());
    if (typeof decoded.id === 'string' && safeId(decoded.id) && typeof decoded.at === 'string' && Number.isFinite(Date.parse(decoded.at))) return decoded;
  } catch (_) { /* invalid cursor */ }
  C.fail('invalid_cursor');
}
function activityCursor(doc) {
  return Buffer.from(JSON.stringify({ id: doc.id, at: C.iso(doc.data().updatedAt || doc.data().latestActivityAt) })).toString('base64url');
}
async function sectionChannels({db, actor, params, section}) {
  const position = activityPosition(params.get('cursor'));
  // updatedAt already exists on historical conversation records and is updated
  // with each visible activity; latestActivityAt is the explicit companion field.
  let query = db.collection('conversations').orderBy('updatedAt', 'desc').orderBy('__name__', 'desc');
  if (position) query = query.startAfter(new Date(position.at), position.id);
  const docs = await query.limit(50).get();
  const allowed = docs.docs.map(doc => ({ id: doc.id, ref: doc.ref, data: doc.data() }))
    .filter(channel => C.access(actor, channel.data).canRead)
    .filter(channel => section === 'direct' ? channel.data.kind === 'direct' : channel.data.kind !== 'direct');
  const result = await boundedMap(allowed, inboxUnreadConcurrency, async channel => channelDto(channel, actor, await unreadCount(channel, actor)));
  return { channels: result, nextCursor: docs.size === 50 ? activityCursor(docs.docs.at(-1)) : null };
}
function userDto(doc, eligibilityReason) {
  const data = doc.data();
  return { id: doc.id, name: data.displayName || data.name || data.employeeName || doc.id, department: P.department(data), eligibilityReason };
}
async function eligibleUsers(db, actor, params) {
  const docs = await pageById(db.collection('users').where('isActive', '==', true), params.get('cursor'), 100).get();
  const actorDoc = await db.collection('users').doc(actor.uid).get();
  const fullActor = actorDoc.exists ? { ...actorDoc.data(), ...actor } : actor;
  const department = params.get('department'), section = params.get('section');
  if (department && department.length > 120) C.fail('validation_failed');
  if (section && !['manager', 'hr', 'admin', 'it'].includes(section)) C.fail('validation_failed');
  const all = docs.docs.map(doc => ({ doc, data: { id: doc.id, ...doc.data() } })).filter(({data}) => P.canDirect(fullActor, data));
  const filtered = all.filter(({data}) => !department || P.department(data) === department).filter(({data}) => !section || (section === 'manager' ? P.isManager(data) : section === 'hr' ? P.isHr(data) && !P.isAdmin(data) : section === 'admin' ? P.isAdmin(data) : P.isIt(data)));
  return { contacts: filtered.map(({doc}) => userDto(doc, section || 'department')), nextCursor: docs.size === 100 ? docs.docs.at(-1).id : null };
}
async function contactDepartments({db, actor, params}) {
  const actorDoc = await db.collection('users').doc(actor.uid).get();
  const fullActor = actorDoc.exists ? { ...actorDoc.data(), ...actor } : actor;
  const docs = await pageById(db.collection('users').where('isActive', '==', true), params.get('cursor'), 100).get();
  const counts = new Map();
  for (const doc of docs.docs) { const target = { id: doc.id, ...doc.data() }; if (P.canDirect(fullActor, target) && P.department(target)) counts.set(P.department(target), (counts.get(P.department(target)) || 0) + 1); }
  return { departments: [...counts].sort(([a],[b]) => a.localeCompare(b, 'ar')).map(([name, eligibleCount]) => ({ id: name, name, eligibleCount })), nextCursor: docs.size === 100 ? docs.docs.at(-1).id : null };
}
async function members({db, channel}) {
  const data = channel.data;
  let docs;
  if (data.kind === 'department') {
    const department = data.departmentName || data.department || data.departmentKey;
    docs = department
      ? (await db.collection('users').where('department', '==', department).limit(100).get()).docs
      : [];
  } else if (data.kind === 'company') {
    docs = (await db.collection('users').where('isActive', '==', true).limit(100).get()).docs;
  } else {
    const ids = [...new Set(Array.isArray(data.memberUserIds) ? data.memberUserIds : [])].slice(0, 100);
    docs = ids.length ? await db.getAll(...ids.map(id => db.collection('users').doc(id))) : [];
  }
  return {
    members: docs
      .filter(doc => doc.exists && doc.data().isActive !== false)
      .map(doc => ({
        id: doc.id,
        name: doc.data().displayName || doc.data().name || doc.data().employeeName || doc.id,
        department: doc.data().department || doc.data().departmentName || '',
      })),
  };
}
async function users({db, params}) {
  const q = (params.get('q') || '').trim().toLocaleLowerCase();
  if (q.length > 120) C.fail('validation_failed');
  const docs = await pageById(db.collection('users').where('isActive', '==', true), params.get('cursor'), 100).get();
  return { users: docs.docs.map(doc => ({ id: doc.id, name: doc.data().displayName || doc.data().name || '', department: doc.data().department || '' })).filter(user => !q || `${user.name} ${user.department}`.toLocaleLowerCase().includes(q)), nextCursor: docs.size === 100 ? docs.docs.at(-1).id : null };
}
async function requests({db, actor, params}) {
  let query = db.collection('conversationRequests');
  if (!C.isHrOrAdmin(actor)) query = query.where('requesterId', '==', actor.uid);
  const docs = await pageById(query, params.get('cursor'), 50).get();
  return { requests: docs.docs.map(doc => ({ ...doc.data(), id: doc.id })), nextCursor: docs.size === 50 ? docs.docs.at(-1).id : null };
}
function historyQuery(channel, before) {
  let query = channel.ref.collection('messages').orderBy('sentAt', 'desc').orderBy('__name__', 'desc');
  const position = C.cursor(before);
  if (position) query = query.startAfter(new Date(position.at), position.id);
  return query;
}
async function history({db, channel, params}) {
  const limit = pageSize(params.get('limit'), 50);
  const docs = await historyQuery(channel, params.get('before')).limit(limit).get();
  return { messages: await C.hydrate(db, docs.docs.map(doc => C.messageDto(doc.id, doc.data()))), nextCursor: docs.size === limit ? C.encodeCursor(docs.docs.at(-1)) : null, changeCursor: String(channel.data.changeSequence || 0), ...presenceDto(channel) };
}
async function changes({db, channel, params}) {
  const after = params.get('after') || '0';
  if (!/^\d{1,16}$/.test(after) || !Number.isSafeInteger(Number(after)) || Number(after) > (channel.data.changeSequence || 0)) C.fail('invalid_cursor');
  const limit = pageSize(params.get('limit'), 100);
  const docs = await channel.ref.collection('changes').where('sequence', '>', Number(after)).orderBy('sequence').limit(limit).get();
  const ids = [...new Set(docs.docs.map(doc => doc.data().messageId).filter(safeId))];
  const snapshots = ids.length ? await db.getAll(...ids.map(id => channel.ref.collection('messages').doc(id))) : [];
  const position = docs.size ? docs.docs.at(-1).data().sequence : Number(after);
  return { messages: await C.hydrate(db, snapshots.filter(d => d.exists).map(d => C.messageDto(d.id, d.data()))), ...presenceDto(channel), changeCursor: String(position), hasMore: position < (channel.data.changeSequence || 0) || docs.size === limit };
}
async function search({db, channel, params}) {
  const q = (params.get('q') || '').trim().toLocaleLowerCase(); if (!q || q.length > 200) C.fail('validation_failed');
  const docs = await historyQuery(channel, params.get('cursor')).limit(200).get();
  const matched = docs.docs.filter(d => d.data().state !== 'deleted' && String(d.data().body || '').toLocaleLowerCase().includes(q));
  return { messages: await C.hydrate(db, matched.map(d => C.messageDto(d.id, d.data()))), nextCursor: docs.size === 200 ? C.encodeCursor(docs.docs.at(-1)) : null, complete: docs.size < 200 };
}
async function audit({db, actor, channel, messageId}) {
  if (!C.isHrOrAdmin(actor)) C.fail('access_denied', 403);
  if (!safeId(messageId)) C.fail('validation_failed');
  const docs = await db.collection('conversationAudit').where('conversationId', '==', channel.id).where('messageId', '==', messageId).orderBy('createdAt', 'desc').limit(100).get();
  return { revisions: docs.docs.map(d => ({ ...d.data(), createdAt: C.iso(d.data().createdAt) })) };
}
module.exports = { channels, users, members, requests, history, changes, search, audit, contactDepartments, eligibleUsers, pageSize, presenceDto, boundedMap };
