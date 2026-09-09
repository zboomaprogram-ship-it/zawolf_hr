'use strict';
const { safeId } = require('../conversation-operations');
const C = require('./common');
const P = require('./direct-policy');
const userDto = (id, data) => ({ id, ...data });
function pair(actorId, targetId) { return [actorId, targetId].sort(); }
async function createDirect({ db, actor, payload, now = new Date() }) {
  if (!safeId(payload.targetUserId)) C.fail('validation_failed');
  const op = C.operation(db, actor, 'direct', payload);
  const ids = pair(actor.uid, payload.targetUserId);
  const pairKey = C.hash(ids).slice(0, 48), id = `direct:${pairKey}`;
  return db.runTransaction(async tx => {
    const prior = C.replay(await tx.get(op.ref), op); if (prior) return prior;
    const docs = await Promise.all(ids.map(userId => tx.get(db.collection('users').doc(userId))));
    if (docs.some(doc => !doc.exists)) C.fail('target_unavailable', 404);
    const [first, second] = docs.map(doc => userDto(doc.id, doc.data()));
    const self = first.id === actor.uid ? first : second;
    const target = first.id === actor.uid ? second : first;
    if (!P.canDirect({ ...self, ...actor }, target)) C.fail('access_denied', 403);
    const ref = db.collection('conversations').doc(id), existing = await tx.get(ref);
    if (!existing.exists) tx.create(ref, {
      kind: 'direct', state: 'active', memberUserIds: ids, participantUserIds: ids, pairKey,
      name: target.displayName || target.name || target.employeeName || target.id,
      createdBy: actor.uid, createdAt: now, updatedAt: now, latestActivityAt: now,
      latestActivityId: id, changeSequence: 0, revision: 1,
    });
    const data = existing.exists ? existing.data() : { kind: 'direct', memberUserIds: ids, participantUserIds: ids, name: target.displayName || target.name || target.id, latestActivityAt: now };
    return C.receipt(tx, op, { channel: { id, name: data.name, kind: 'direct', canPost: true, memberUserIds: ids, participantUserIds: ids, revision: data.revision || 1 } }, now);
  });
}
module.exports = { pair, createDirect };
