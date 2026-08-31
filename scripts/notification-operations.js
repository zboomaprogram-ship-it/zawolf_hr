'use strict';

const {
  classifyRecipientRoute,
  normalizeNotificationResource,
} = require('./dispatch-notifications');

const OPERATION_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/;
const NOTIFICATION_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/;
const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 100;
const DEFAULT_MAX_PAGES = 5;
const MAX_PAGES = 10;

function normalizeBoundedInteger(value, fallback, maximum) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 1) return fallback;
  return Math.min(maximum, Math.floor(parsed));
}

function normalizeMarkAllRequest(input = {}) {
  const operationId = String(input.operationId || '').trim();
  if (!OPERATION_ID_PATTERN.test(operationId)) return null;
  return {
    operationId,
    pageSize: normalizeBoundedInteger(
      input.pageSize,
      DEFAULT_PAGE_SIZE,
      MAX_PAGE_SIZE,
    ),
    maxPages: normalizeBoundedInteger(
      input.maxPages,
      DEFAULT_MAX_PAGES,
      MAX_PAGES,
    ),
  };
}

function normalizeResolveRequest(input = {}) {
  const notificationId = String(input.notificationId || '').trim();
  return NOTIFICATION_ID_PATTERN.test(notificationId)
    ? { notificationId }
    : null;
}

async function markAllNotificationsRead({ db, fieldValue, actorId, input }) {
  const request = normalizeMarkAllRequest(input);
  if (!request || !NOTIFICATION_ID_PATTERN.test(String(actorId || ''))) {
    return { ok: false, code: 'validation_failed' };
  }

  const userRef = db.collection('users').doc(actorId);
  const operationRef = db.collection('notificationReadOperations')
    .doc(`${actorId}:${request.operationId}`);
  const existing = await operationRef.get();
  if (existing.exists && existing.data()?.status === 'complete') {
    return {
      ok: true,
      code: 'all_read',
      complete: true,
      changed: Number(existing.data()?.changed || 0),
    };
  }

  let changed = Number(existing.data()?.changed || 0);
  let complete = false;
  for (let page = 0; page < request.maxPages; page++) {
    const snapshot = await db.collection('notifications').doc(actorId)
      .collection('items')
      .where('isRead', '==', false)
      .limit(request.pageSize)
      .get();
    const docs = snapshot?.docs || [];
    if (docs.length === 0) {
      complete = true;
      break;
    }

    const batch = db.batch();
    for (const doc of docs) {
      batch.update(doc.ref, {
        isRead: true,
        readAt: fieldValue.serverTimestamp(),
      });
    }
    changed += docs.length;
    batch.set(operationRef, {
      actorId,
      status: 'in_progress',
      changed,
      updatedAt: fieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();

    if (docs.length < request.pageSize) {
      complete = true;
      break;
    }
  }

  const finalBatch = db.batch();
  if (complete) {
    finalBatch.set(userRef, {
      unreadNotifications: 0,
      notificationReadVersion: fieldValue.increment(1),
      notificationsReadAt: fieldValue.serverTimestamp(),
    }, { merge: true });
  }
  finalBatch.set(operationRef, {
    actorId,
    status: complete ? 'complete' : 'in_progress',
    changed,
    updatedAt: fieldValue.serverTimestamp(),
    ...(complete ? { completedAt: fieldValue.serverTimestamp() } : {}),
  }, { merge: true });
  await finalBatch.commit();

  return {
    ok: true,
    code: complete ? 'all_read' : 'more_pending',
    complete,
    changed,
  };
}

async function resolveNotificationDestination({ db, actor, input }) {
  const request = normalizeResolveRequest(input);
  if (!request || !NOTIFICATION_ID_PATTERN.test(String(actor?.uid || ''))) {
    return { ok: false, code: 'validation_failed' };
  }

  const item = await db.collection('notifications').doc(actor.uid)
    .collection('items').doc(request.notificationId).get();
  if (!item.exists) {
    return { ok: false, code: 'not_found' };
  }
  const destination = classifyRecipientRoute({
    role: actor.role,
    resource: normalizeNotificationResource(item.data() || {}),
  });
  return {
    ok: true,
    code: 'resolved',
    destination,
  };
}

module.exports = {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  DEFAULT_MAX_PAGES,
  MAX_PAGES,
  normalizeMarkAllRequest,
  normalizeResolveRequest,
  markAllNotificationsRead,
  resolveNotificationDestination,
};
