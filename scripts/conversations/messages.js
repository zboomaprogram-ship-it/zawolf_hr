'use strict';
const { normalizeMessageInput, safeId } = require('../conversation-operations');
const C = require('./common');
const displayName = actor => actor.displayName || actor.name || actor.employeeId || '';
async function sendMessage({ db, admin, actor, channelId, payload, legacy = false, now = new Date() }) {
  const input = normalizeMessageInput(payload);
  if (!input || (payload.replyToMessageId && !safeId(payload.replyToMessageId))) C.fail('validation_failed');
  const op = C.operation(db, actor, `send:${channelId}`, payload);
  return db.runTransaction(async tx => {
    const channel = await C.channelFor(db, actor, channelId, tx, true);
    const prior = C.replay(await tx.get(op.ref), op);
    if (prior) return prior;
    const messageId = legacy ? input.operationId : C.hash(actor.uid, input.operationId).slice(0, 48);
    const ref = channel.ref.collection('messages').doc(messageId);
    const existing = await tx.get(ref);
    if (existing.exists) {
      const old = existing.data();
      if (old.senderUserId !== actor.uid || old.body !== input.body || JSON.stringify(old.attachmentResourceIds || []) !== JSON.stringify(input.attachmentResourceIds)) C.fail('operation_conflict', 409);
      return C.receipt(tx, op, { message: C.messageDto(ref.id, old) }, now);
    }
    const attachments = [];
    for (const id of input.attachmentResourceIds) {
      const doc = await tx.get(db.collection('conversationAttachments').doc(id));
      const data = doc.data();
      if (!doc.exists || data.conversationId !== channelId || data.status !== 'uploaded') C.fail('access_denied', 403);
      attachments.push(C.attachmentDto(id, data));
    }
    if (payload.replyToMessageId) {
      const reply = await tx.get(channel.ref.collection('messages').doc(payload.replyToMessageId));
      if (!reply.exists || reply.data().state === 'deleted') C.fail('reply_unavailable', 409);
    }
    const message = { conversationId: channelId, senderUserId: actor.uid, senderDisplayName: displayName(actor), body: input.body, attachmentResourceIds: input.attachmentResourceIds, attachments, replyToMessageId: payload.replyToMessageId || null, sentAt: now, state: 'sent', revision: 1, reactions: {}, forwarded: false };
    tx.create(ref, message);
    C.change(tx, channel, 'message', { messageId }, now);
    C.audit(tx, db, channelId, input.operationId, actor, 'send', { messageId, revision: 1, message: C.messageDto(messageId, message) }, now);
    C.notify(tx, db, (channel.data.memberUserIds || []).filter(id => id !== actor.uid), `send:${channelId}:${messageId}`, 'رسالة جديدة', input.body || 'مرفق جديد', { conversationId: channelId, messageId, route: `/conversations/channel/${encodeURIComponent(channelId)}` }, now, admin);
    return C.receipt(tx, op, { message: C.messageDto(messageId, message) }, now);
  });
}
function validateSenderAction(actor, message, payload, now) {
  if (message.senderUserId !== actor.uid) C.fail('access_denied', 403);
  if (message.state === 'deleted') C.fail('message_deleted', 409);
  if (Number(payload.expectedRevision) !== (message.revision || 1)) C.fail('revision_conflict', 409);
  const sent = Date.parse(C.iso(message.sentAt));
  if (!Number.isFinite(sent) || now.getTime() - sent > 15 * 60 * 1000 || now.getTime() < sent) C.fail('edit_window_expired', 409);
}
async function messageAction({ db, admin, actor, channelId, messageId, payload, now = new Date() }) {
  if (!safeId(messageId) || !['edit', 'delete', 'react', 'forward'].includes(payload.action)) C.fail('validation_failed');
  const op = C.operation(db, actor, `action:${channelId}:${messageId}`, payload);
  return db.runTransaction(async tx => {
    const source = await C.channelFor(db, actor, channelId, tx, true);
    const prior = C.replay(await tx.get(op.ref), op);
    if (prior) return prior;
    const ref = source.ref.collection('messages').doc(messageId);
    const snap = await tx.get(ref);
    if (!snap.exists) C.fail('message_unavailable', 404);
    const old = snap.data();
    if (old.state === 'deleted') C.fail('message_deleted', 409);
    let channel = source, id = messageId, target = ref;
    let next = { ...old, revision: (old.revision || 1) + 1 };
    if (payload.action === 'edit' || payload.action === 'delete') {
      validateSenderAction(actor, old, payload, now);
      if (payload.action === 'edit') {
        const normalized = normalizeMessageInput({ operationId: payload.operationId, body: payload.body, attachmentResourceIds: old.attachmentResourceIds || [] });
        if (!normalized) C.fail('validation_failed');
        next = { ...next, body: normalized.body, editedAt: now };
      } else next = { ...next, body: '', state: 'deleted', attachmentResourceIds: [], attachments: [], reactions: {}, deletedAt: now };
    } else if (payload.action === 'react') {
      if (typeof payload.emoji !== 'string' || !payload.emoji.trim() || [...payload.emoji].length > 16 || /[\p{L}\p{N}\s]/u.test(payload.emoji)) C.fail('validation_failed');
      const reactions = { ...(old.reactions || {}) };
      if (reactions[actor.uid] === payload.emoji) delete reactions[actor.uid]; else reactions[actor.uid] = payload.emoji;
      next.reactions = reactions;
    } else {
      channel = await C.channelFor(db, actor, payload.destinationId, tx, true);
      id = C.hash(actor.uid, payload.operationId, 'forward').slice(0, 48);
      target = channel.ref.collection('messages').doc(id);
      const resources = [];
      for (const resourceId of old.attachmentResourceIds || []) {
        const doc = await tx.get(db.collection('conversationAttachments').doc(resourceId));
        const data = doc.data();
        if (!doc.exists || data.conversationId !== channelId || data.status !== 'uploaded') C.fail('attachment_unavailable', 409);
        const destinationResourceId = C.hash(channel.id, id, resourceId).slice(0, 48);
        resources.push({ id: destinationResourceId, data: { ...data, conversationId: channel.id, resourceId: destinationResourceId, uploadedBy: actor.uid, createdAt: now } });
      }
      // Complete all transactional reads before allocating destination-bound resources.
      for (const resource of resources) tx.set(db.collection('conversationAttachments').doc(resource.id), resource.data);
      next = { conversationId: channel.id, senderUserId: actor.uid, senderDisplayName: displayName(actor), body: old.body || '', attachmentResourceIds: resources.map(r => r.id), attachments: resources.map(r => C.attachmentDto(r.id, r.data)), replyToMessageId: null, sentAt: now, state: 'sent', revision: 1, reactions: {}, forwarded: true };
    }
    tx.set(target, next);
    C.change(tx, channel, 'message', { messageId: id }, now);
    C.audit(tx, db, channel.id, payload.operationId, actor, payload.action, { messageId: id, revision: next.revision, previous: C.messageDto(messageId, old), message: C.messageDto(id, next) }, now);
    if (payload.action === 'forward') C.notify(tx, db, (channel.data.memberUserIds || []).filter(uid => uid !== actor.uid), `forward:${id}`, 'رسالة جديدة', next.body || 'مرفق جديد', { conversationId: channel.id, messageId: id, route: `/conversations/channel/${encodeURIComponent(channel.id)}` }, now, admin);
    return C.receipt(tx, op, { message: C.messageDto(id, next) }, now);
  });
}
async function presence({ db, actor, channelId, payload, typing = false, now = new Date() }) {
  const op = C.operation(db, actor, `${typing ? 'typing' : 'read'}:${channelId}`, payload);
  return db.runTransaction(async tx => {
    const channel = await C.channelFor(db, actor, channelId, tx, true);
    const previous = C.replay(await tx.get(op.ref), op); if (previous) return previous;
    if (typing) {
      if (typeof payload.typing !== 'boolean') C.fail('validation_failed');
      const current = channel.data.typing || {};
      const next = { ...current, [actor.uid]: { userId: actor.uid, name: displayName(actor), expiresAt: new Date(now.getTime() + (payload.typing ? 10000 : 0)).toISOString() } };
      for (const [uid, entry] of Object.entries(next)) if (Date.parse(entry.expiresAt) <= now.getTime()) delete next[uid];
      tx.update(channel.ref, { typing: next });
      C.change(tx, channel, 'typing', {}, now);
      return C.receipt(tx, op, { ok: true }, now);
    }
    if (!safeId(payload.messageId)) C.fail('validation_failed');
    const message = await tx.get(channel.ref.collection('messages').doc(payload.messageId));
    if (!message.exists) C.fail('message_unavailable', 404);
    const readers = { ...(channel.data.readers || {}) };
    const sentAt = C.iso(message.data().sentAt);
    const old = readers[actor.uid];
    if (!old || sentAt > old.sentAt || (sentAt === old.sentAt && payload.messageId > old.messageId)) {
      readers[actor.uid] = { messageId: payload.messageId, readAt: now.toISOString(), sentAt, name: displayName(actor) };
      tx.set(channel.ref, { readers }, { merge: true });
      C.change(tx, channel, 'read', {}, now);
    }
    return C.receipt(tx, op, { readers }, now);
  });
}
module.exports = { sendMessage, messageAction, presence, validateSenderAction };
