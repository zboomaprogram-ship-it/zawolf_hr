'use strict';
const { safeId } = require('../conversation-operations');
const C = require('./common');
function members(values, requesterId) {
  if (!Array.isArray(values) || values.some(id => !safeId(id))) C.fail('validation_failed');
  const ids = [...new Set([...values, requesterId])].sort();
  if (ids.length < 2 || ids.length > 100) C.fail('validation_failed');
  return ids;
}
function name(value) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 120) C.fail('validation_failed');
  return value.trim();
}
function reason(value) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 2000) C.fail('validation_failed');
  return value.trim();
}
async function activeMembers(tx, db, ids) {
  for (const id of ids) { const user = await tx.get(db.collection('users').doc(id)); if (!user.exists || user.data().isActive !== true) C.fail('inactive_member', 409); }
}
function reviewState(old, payload) {
  if (old.status !== 'pending' || Number(payload.expectedRevision) !== old.revision) C.fail('revision_conflict', 409);
  if (!['approved', 'rejected'].includes(payload.decision)) C.fail('validation_failed');
}
async function createRequest({ db, admin, actor, payload, now = new Date() }) {
  const memberUserIds = members(payload.memberUserIds, actor.uid);
  const requestName = name(payload.name), requestReason = reason(payload.reason);
  const op = C.operation(db, actor, 'request', payload);
  const id = C.hash(actor.uid, payload.operationId).slice(0, 48);
  // Bounded canonical reviewer lookup; notifications use the existing dispatcher.
  const reviewers = await db.collection('users').where('isActive', '==', true).where('role', 'in', ['hr', 'hr_admin', 'hr_manager', 'admin', 'administrator', 'super_admin', 'owner']).limit(100).get();
  return db.runTransaction(async tx => {
    const prior = C.replay(await tx.get(op.ref), op); if (prior) return prior;
    await activeMembers(tx, db, memberUserIds);
    const request = { id, name: requestName, reason: requestReason, memberUserIds, requesterId: actor.uid, status: 'pending', revision: 1, rejectionReason: null, conversationId: null, createdAt: now.toISOString() };
    tx.create(db.collection('conversationRequests').doc(id), request);
    C.audit(tx, db, id, payload.operationId, actor, 'request', { request }, now);
    C.notify(tx, db, reviewers.docs.map(d => d.id), `request:${id}`, 'طلب جروب محادثة', requestName, { requestId: id, route: '/conversations/requests' }, now, admin);
    return C.receipt(tx, op, { request }, now);
  });
}
async function reviewRequest({ db, admin, actor, requestId, payload, now = new Date() }) {
  if (!C.isHrOrAdmin(actor)) C.fail('access_denied', 403);
  if (!safeId(requestId)) C.fail('validation_failed');
  const op = C.operation(db, actor, `review:${requestId}`, payload);
  return db.runTransaction(async tx => {
    const prior = C.replay(await tx.get(op.ref), op); if (prior) return prior;
    const ref = db.collection('conversationRequests').doc(requestId), doc = await tx.get(ref);
    if (!doc.exists) C.fail('request_unavailable', 404);
    const old = doc.data(); reviewState(old, payload);
    const request = { ...old, status: payload.decision, revision: old.revision + 1, reviewedBy: actor.uid, reviewedAt: now.toISOString() };
    if (payload.decision === 'approved') {
      request.name = name(payload.name === undefined ? old.name : payload.name);
      request.memberUserIds = members(payload.memberUserIds === undefined ? old.memberUserIds : payload.memberUserIds, old.requesterId);
      await activeMembers(tx, db, request.memberUserIds);
      request.conversationId = `custom:${C.hash(requestId).slice(0, 48)}`;
      tx.create(db.collection('conversations').doc(request.conversationId), { name: request.name, purposeAr: request.name, kind: 'custom', approved: true, state: 'active', memberUserIds: request.memberUserIds, revision: 1, requestId, createdBy: old.requesterId, createdAt: now, updatedAt: now, latestActivityAt: now, latestActivityId: request.conversationId, changeSequence: 0 });
    } else request.rejectionReason = reason(payload.reason);
    tx.set(ref, request);
    C.audit(tx, db, request.conversationId || requestId, payload.operationId, actor, 'review', { request }, now);
    C.notify(tx, db, payload.decision === 'approved' ? request.memberUserIds : [old.requesterId], `review:${requestId}`, 'تحديث طلب المحادثة', payload.decision === 'approved' ? 'تمت الموافقة على الجروب' : 'تم رفض الطلب', { requestId, conversationId: request.conversationId, route: request.conversationId ? `/conversations/${encodeURIComponent(request.conversationId)}` : '/conversations/requests' }, now, admin);
    return C.receipt(tx, op, { request }, now);
  });
}
async function updateMembers({ db, admin, actor, channelId, payload, now = new Date() }) {
  if (!C.isHrOrAdmin(actor)) C.fail('access_denied', 403);
  const op = C.operation(db, actor, `members:${channelId}`, payload);
  return db.runTransaction(async tx => {
    const channel = await C.channelFor(db, actor, channelId, tx);
    const prior = C.replay(await tx.get(op.ref), op); if (prior) return prior;
    if (channel.data.kind !== 'custom' || channel.data.approved !== true) C.fail('access_denied', 403);
    if (Number(payload.expectedRevision) !== (channel.data.revision || 1)) C.fail('revision_conflict', 409);
    // HR can remove any member, including the requester, after approval.
    if (!Array.isArray(payload.memberUserIds) || payload.memberUserIds.some(id => !safeId(id))) C.fail('validation_failed');
    const ids = [...new Set(payload.memberUserIds)].sort(); if (ids.length < 2 || ids.length > 100) C.fail('validation_failed');
    await activeMembers(tx, db, ids);
    const data = { ...channel.data, memberUserIds: ids, revision: (channel.data.revision || 1) + 1 };
    tx.set(channel.ref, data);
    C.change(tx, channel, 'members', {}, now);
    C.audit(tx, db, channelId, payload.operationId, actor, 'members', { memberUserIds: ids, revision: data.revision }, now);
    C.notify(tx, db, ids.filter(id => !channel.data.memberUserIds.includes(id)), `members:${channelId}:${payload.operationId}`, 'تمت إضافتك إلى جروب', data.name, { conversationId: channelId, route: `/conversations/${encodeURIComponent(channelId)}` }, now, admin);
    return C.receipt(tx, op, { channel: channelDto({ ...channel, data }, actor) }, now);
  });
}
function channelDto(channel, actor, unreadCount = 0) {
  const permissions = C.access(actor, channel.data);
  return { id: channel.id, name: channel.data.name || channel.data.purposeAr || channel.data.departmentName || '', kind: channel.data.kind || 'conversation', canPost: permissions.canPost, memberUserIds: channel.data.memberUserIds || [], participantUserIds: channel.data.participantUserIds || [], unreadCount, hrReadable: channel.data.kind === 'custom' && channel.data.approved === true, revision: channel.data.revision || 1, latestActivityAt: C.iso(channel.data.latestActivityAt || channel.data.updatedAt || channel.data.createdAt) || null, latestActivityId: channel.data.latestActivityId || channel.id };
}
module.exports = { members, reviewState, createRequest, reviewRequest, updateMembers, channelDto };
