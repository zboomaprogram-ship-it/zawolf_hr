'use strict';
const crypto = require('node:crypto');
const { safeId, canAccessDepartment, isConversationMember } = require('../conversation-operations');
const { isHrOrAdmin } = require('../phase007-authorization');
const hash = (...parts) => crypto.createHash('sha256').update(JSON.stringify(parts)).digest('hex');
const notificationPreferenceId = (channelId, userId) => `chat_pref_${hash(channelId, userId).slice(0, 40)}`;
const iso = value => value?.toDate?.().toISOString() || (value instanceof Date ? value.toISOString() : typeof value === 'string' ? value : '');
function fail(code, status = 400) { throw Object.assign(new Error(code), { code, status }); }
function access(actor, data) {
  if (!actor?.uid || actor.active === false || !data || data.state === 'closed') return { canRead: false, canPost: false };
  const deptName = data.departmentName || data.department || data.departmentKey;
  const direct = data.kind === 'direct';
  if (data.kind === 'company') return { canRead: true, canPost: true };
  const participantIds = Array.isArray(data.participantUserIds) ? data.participantUserIds : data.memberUserIds;
  const member = direct
    ? participantIds.length === 2 && participantIds.includes(actor.uid)
    : data.kind === 'department' ? canAccessDepartment(actor, deptName) : isConversationMember(data, actor.uid);
  // HR and admins moderate approved custom groups without being injected into
  // every memberUserIds list, so they retain access as membership changes.
  const moderator = data.kind === 'custom' && data.approved === true && isHrOrAdmin(actor);
  return { canRead: member || moderator, canPost: member || moderator };
}
async function channelFor(db, actor, id, tx, write = false) {
  if (!safeId(id)) fail('access_denied', 403);
  const ref = db.collection('conversations').doc(id);
  const snap = await (tx ? tx.get(ref) : ref.get());
  const data = snap.exists ? snap.data() : null;
  const permissions = access(actor, data);
  // A direct conversation remains readable for its existing participants when
  // one account is deactivated, but neither participant may create new
  // messages or actions. Resolve this from current user records rather than a
  // stale channel member list.
  if (permissions.canRead && data?.kind === 'direct') {
    const ids = Array.isArray(data.participantUserIds)
      ? data.participantUserIds
      : data.memberUserIds || [];
    const users = await Promise.all(
      ids.map(userId => tx
        ? tx.get(db.collection('users').doc(userId))
        : db.collection('users').doc(userId).get()),
    );
    permissions.canPost = users.length === 2 && users.every(user =>
      user.exists && user.data().isActive !== false);
  }
  if (!permissions.canRead || (write && !permissions.canPost)) fail('access_denied', 403);
  return { id, ref, data, ...permissions };
}
function attachmentDto(id, data) {
  const dto = { resourceId: id, fileName: data.fileName || data.name || '', mimeType: data.mimeType || 'application/octet-stream', sizeBytes: data.sizeBytes || 0, kind: data.kind || 'file', status: data.status || 'uploaded' };
  for (const key of ['width', 'height', 'durationSeconds']) if (Number.isFinite(data[key])) dto[key] = data[key];
  return dto;
}
function messageDto(id, data) {
  return { id, conversationId: data.conversationId, senderUserId: data.senderUserId || '', senderDisplayName: data.senderDisplayName || '', body: data.state === 'deleted' ? '' : data.body || '', stickerId: data.state === 'deleted' ? null : data.stickerId || null, sentAt: iso(data.sentAt), state: data.state || 'sent', attachmentResourceIds: data.state === 'deleted' ? [] : data.attachmentResourceIds || [], attachments: data.state === 'deleted' ? [] : data.attachments || [], replyToMessageId: data.replyToMessageId || null, forwarded: data.forwarded || false, revision: data.revision || 1, editedAt: iso(data.editedAt) || null, deletedAt: iso(data.deletedAt) || null, reactions: data.state === 'deleted' ? {} : data.reactions || {} };
}
async function hydrate(db, messages) {
  const missing = [...new Set(messages.flatMap(m => m.attachmentResourceIds.filter(id => !m.attachments.some(a => a.resourceId === id))))];
  const resources = new Map();
  for (let offset = 0; offset < missing.length; offset += 100) {
    const docs = await db.getAll(...missing.slice(offset, offset + 100).map(id => db.collection('conversationAttachments').doc(id)));
    for (const doc of docs) if (doc.exists) resources.set(doc.id, doc.data());
  }
  return messages.map(m => ({ ...m, attachments: m.attachmentResourceIds.map(id => m.attachments.find(a => a.resourceId === id) || (resources.get(id)?.conversationId === m.conversationId ? attachmentDto(id, resources.get(id)) : {resourceId:id,fileName:'',mimeType:'application/octet-stream',sizeBytes:0,kind:'file',status:'unavailable'})) }));
}
function cursor(value) {
  if (!value) return null;
  try { const v = JSON.parse(Buffer.from(value, 'base64url').toString()); if (typeof v.id === 'string' && safeId(v.id) && typeof v.at === 'string' && Number.isFinite(Date.parse(v.at))) return v; } catch (_) { /* invalid cursor */ }
  fail('invalid_cursor');
}
const encodeCursor = (doc) => doc ? Buffer.from(JSON.stringify({ id: doc.id, at: iso(doc.data().sentAt) })).toString('base64url') : null;
function change(tx, channel, type, data, now) {
  const sequence = (channel.data.changeSequence || 0) + 1;
  tx.set(channel.ref.collection('changes').doc(String(sequence).padStart(16, '0')), { sequence, type, ...data, at: now });
  const activity = !['read', 'typing', 'members'].includes(type);
  tx.set(channel.ref, { changeSequence: sequence, updatedAt: now, ...(activity ? { latestActivityAt: now, latestActivityId: data.messageId || `${sequence}` } : {}) }, { merge: true });
  return sequence;
}
function audit(tx, db, channelId, operationId, actor, action, data, now) {
  tx.set(db.collection('conversationAudit').doc(hash(channelId, actor.uid, operationId)), { conversationId: channelId, operationId, actorId: actor.uid, action, ...data, createdAt: now });
}
function operation(db, actor, scope, payload) {
  if (!safeId(payload.operationId)) fail('validation_failed');
  return { ref: db.collection('conversationOperations').doc(hash(actor.uid, scope, payload.operationId)), fingerprint: hash(payload) };
}
function replay(snap, op) {
  if (!snap.exists) return null;
  if (snap.data().fingerprint !== op.fingerprint) fail('operation_conflict', 409);
  return snap.data().result;
}
function receipt(tx, op, result, now) { tx.set(op.ref, { fingerprint: op.fingerprint, result, createdAt: now }); return result; }
function notify(tx, db, ids, key, title, body, data, now, admin) {
  for (const id of [...new Set(ids)].filter(safeId)) {
    const notificationId = `chat_${hash(key, id).slice(0, 40)}`;
    tx.set(db.collection('notifications').doc(id).collection('items').doc(notificationId), { notificationId, type: 'conversation', title, body, data, isRead: false, pushSent: false, createdAt: now });
    if (admin) tx.set(db.collection('users').doc(id), { unreadNotifications: admin.firestore.FieldValue.increment(1) }, { merge: true });
  }
}
// Company conversations deliberately do not duplicate every employee id onto
// the channel document. Fan-out is therefore deferred to the notification
// runtime, which pages active users and retains a durable cursor/retry state.
function notifyChannel(tx, db, channel, senderId, key, title, body, data, now, admin) {
  if (channel.data.kind !== 'company') {
    notify(tx, db, (channel.data.memberUserIds || []).filter(id => id !== senderId), key, title, body, data, now, admin);
    return;
  }
  const id = `chat_${hash(key).slice(0, 40)}`;
  tx.set(db.collection('conversationNotificationOutbox').doc(id), {
    id,
    type: 'conversation',
    conversationId: channel.id,
    senderUserId: senderId,
    title,
    body,
    data,
    dispatchStatus: 'pending',
    cursor: null,
    createdAt: now,
  }, { merge: true });
}
module.exports = { hash, notificationPreferenceId, iso, fail, access, channelFor, attachmentDto, messageDto, hydrate, cursor, encodeCursor, change, audit, operation, replay, receipt, notify, notifyChannel, isHrOrAdmin };
