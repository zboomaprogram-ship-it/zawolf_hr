'use strict';
const { safeId } = require('../conversation-operations');
const C = require('./common');
const { channelDto } = require('./requests');
const pageSize = (value, max) => Math.min(max, Math.max(1, Number.parseInt(value, 10) || max));
function presenceDto(channel, now = new Date()) {
  return { readers: channel.data.readers || {}, typing: Object.values(channel.data.typing || {}).filter(v => Date.parse(v.expiresAt) > now.getTime()), canPost: channel.canPost };
}
function pageById(query, value, limit) {
  if (value && !safeId(value)) C.fail('invalid_cursor');
  query = query.orderBy('__name__');
  if (value) query = query.startAfter(value);
  return query.limit(limit);
}
async function channels({db, actor, params}) {
  // One bounded page across legacy and custom channels avoids an unbounded merge
  // and gives stable pagination even when authorization filters a whole page.
  const docs = await pageById(db.collection('conversations'), params.get('cursor'), 50).get();
  const result = [];
  for (const doc of docs.docs) {
    const data = doc.data(); if (!C.access(actor, data).canRead) continue;
    const read = data.readers?.[actor.uid];
    let unreadCount = 0;
    try {
      const snaps = await doc.ref.collection('messages').orderBy('sentAt', 'desc').limit(100).get();
      if (read?.sentAt) {
        const at = new Date(read.sentAt).getTime();
        unreadCount = snaps.docs.filter(d => {
          const m = d.data();
          if (m.senderUserId === actor.uid) return false;
          const msgTime = (m.sentAt?.toDate ? m.sentAt.toDate() : new Date(m.sentAt || 0)).getTime();
          return msgTime > at || (msgTime === at && d.id > (read.messageId || ''));
        }).length;
      } else {
        unreadCount = snaps.docs.filter(d => d.data().senderUserId !== actor.uid).length;
      }
    } catch (_) {
      unreadCount = 0;
    }
    result.push(channelDto({ id: doc.id, data }, actor, unreadCount));
  }
  return { channels: result, nextCursor: docs.size === 50 ? docs.docs.at(-1).id : null };
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
module.exports = { channels, users, requests, history, changes, search, audit, pageSize, presenceDto };
