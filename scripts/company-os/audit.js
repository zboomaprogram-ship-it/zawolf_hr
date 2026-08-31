'use strict';

const { redactPrivateFields } = require('./safe-errors');

function buildAuditEvent({ operationId, actor, action, targetType, targetId, safeBefore = {}, safeAfter = {}, now = new Date() }) {
  return Object.freeze({
    id: operationId,
    operationId,
    actorUid: actor.uid,
    actorRole: actor.role,
    action,
    targetType,
    targetId,
    safeBefore: redactPrivateFields(safeBefore),
    safeAfter: redactPrivateFields(safeAfter),
    createdAt: now,
  });
}

module.exports = { buildAuditEvent };

