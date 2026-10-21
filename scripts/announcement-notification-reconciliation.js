'use strict';

const crypto = require('node:crypto');

const DEFAULT_PUSH_MAX_AGE_MINUTES = 6 * 60;
const USER_PAGE_SIZE = 200;
const MAX_USER_PAGES = 25;

function timestampDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value.toMillis === 'function') return new Date(value.toMillis());
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function isActiveUser(data) {
  return data?.isActive !== false;
}

function normalized(value) {
  return String(value || '').trim().toLocaleLowerCase();
}

function userDepartment(data) {
  return normalized(
    data?.department || data?.departmentName || data?.departmentKey ||
      data?.departmentId || data?.dept,
  );
}

function userLocation(data) {
  return normalized(
    data?.locationId || data?.assignedLocationId || data?.attendanceLocationId,
  );
}

function audienceUserIds(announcement, users) {
  const group = normalized(announcement?.targetGroup || 'all');
  const explicit = new Set(
    (Array.isArray(announcement?.targetUserIds) ? announcement.targetUserIds : [])
      .map(String)
      .filter(Boolean),
  );
  const active = users.filter((user) => isActiveUser(user.data || {}));

  // Global announcements must resolve against the authoritative user directory.
  // Older clients stored an incomplete targetUserIds list when isActive was absent.
  if (group === 'all') return active.map((user) => user.id);
  if (group === 'managers_only') {
    const roles = new Set(['manager', 'team_leader']);
    return active.filter((user) => roles.has(normalized(user.data?.role))).map((user) => user.id);
  }
  if (group === 'department') {
    const departments = new Set(
      (Array.isArray(announcement?.targetDepartments) ? announcement.targetDepartments : [])
        .map(normalized)
        .filter(Boolean),
    );
    if (departments.size) {
      return active.filter((user) => departments.has(userDepartment(user.data))).map((user) => user.id);
    }
  }
  if (group === 'location' && announcement?.targetLocationId) {
    const locationId = normalized(announcement.targetLocationId);
    return active.filter((user) => userLocation(user.data) === locationId).map((user) => user.id);
  }

  // Selected, assigned-team and legacy targeted announcements keep the audience
  // captured by the sender. This prevents reconciliation from widening access.
  return active.filter((user) => explicit.has(user.id)).map((user) => user.id);
}

function notificationId(announcementId, userId) {
  return `announcement_${crypto.createHash('sha256')
    .update(`${announcementId}:${userId}`)
    .digest('hex')
    .slice(0, 40)}`;
}

function pushExpiryDate(announcement, now = new Date(), maxAgeMinutes = DEFAULT_PUSH_MAX_AGE_MINUTES) {
  const createdAt = timestampDate(announcement?.createdAt);
  if (!createdAt) return new Date(now.getTime() - 1);
  return new Date(createdAt.getTime() + maxAgeMinutes * 60 * 1000);
}

function buildNotification({ announcementId, announcement, now, admin }) {
  const announcementDate = timestampDate(announcement?.createdAt);
  const expiresAt = pushExpiryDate(announcement, now);
  const expired = expiresAt.getTime() <= now.getTime();
  return {
    type: 'hr_announcement',
    title: String(announcement?.title || '').startsWith('إعلان إداري:')
      ? String(announcement.title)
      : `إعلان إداري: ${String(announcement?.title || '')}`,
    body: String(announcement?.body || ''),
    data: { announcementId, route: '/notifications' },
    // Historical repair is archive restoration, not a newly delivered alert.
    // Mark it read so the client's unread listener does not emit local alerts.
    isRead: expired,
    pushSent: expired,
    pushDeliveryStatus: expired ? 'expired' : 'pending',
    pushExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: announcementDate
      ? admin.firestore.Timestamp.fromDate(announcementDate)
      : admin.firestore.FieldValue.serverTimestamp(),
    ...(expired ? {
      pushSkippedReason: 'announcement_expired',
      pushFinishedAt: admin.firestore.FieldValue.serverTimestamp(),
    } : {}),
  };
}

async function loadUsers(db, admin) {
  const users = [];
  let cursor = null;
  for (let page = 0; page < MAX_USER_PAGES; page++) {
    let query = db.collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(USER_PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    users.push(...snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} })));
    if (snapshot.size < USER_PAGE_SIZE) break;
    cursor = snapshot.docs.at(-1);
  }
  return users;
}

async function hasLegacyNotification(db, userId, announcementId) {
  const snapshot = await db.collection('notifications').doc(userId).collection('items')
    .where('data.announcementId', '==', announcementId)
    .limit(1)
    .get();
  return !snapshot.empty;
}

async function ensureRecipientNotification({ db, admin, announcementId, announcement, userId, now }) {
  const id = notificationId(announcementId, userId);
  const notificationRef = db.collection('notifications').doc(userId).collection('items').doc(id);
  const userRef = db.collection('users').doc(userId);
  const payload = {
    notificationId: id,
    ...buildNotification({ announcementId, announcement, now, admin }),
  };
  const deterministicExisting = await notificationRef.get();
  if (deterministicExisting.exists) {
    // Version 1 restored old announcements as unread with the repair time.
    // Normalize those records without removing them from notification history.
    if (payload.isRead === true && deterministicExisting.data()?.isRead !== true) {
      await db.runTransaction(async (transaction) => {
        const notification = await transaction.get(notificationRef);
        const user = await transaction.get(userRef);
        if (!notification.exists || notification.data()?.isRead === true) return;
        transaction.update(notificationRef, {
          isRead: true,
          createdAt: payload.createdAt,
          pushSent: true,
          pushDeliveryStatus: 'expired',
          pushSkippedReason: 'announcement_expired',
          pushFinishedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (user.exists) {
          const unread = Number(user.data()?.unreadNotifications || 0);
          transaction.set(userRef, {
            unreadNotifications: Math.max(0, Number.isFinite(unread) ? unread - 1 : 0),
          }, { merge: true });
        }
      });
    }
    return false;
  }
  if (await hasLegacyNotification(db, userId, announcementId)) return false;
  return db.runTransaction(async (transaction) => {
    const existing = await transaction.get(notificationRef);
    if (existing.exists) return false;
    transaction.create(notificationRef, payload);
    if (payload.isRead !== true) {
      transaction.set(userRef, {
        unreadNotifications: admin.firestore.FieldValue.increment(1),
      }, { merge: true });
    }
    return true;
  });
}

async function reconcileAnnouncement({ db, admin, announcementDoc, now = new Date(), users: suppliedUsers }) {
  if (!announcementDoc?.exists) return { announcementId: '', recipients: 0, created: 0 };
  const announcementId = announcementDoc.id;
  const announcement = announcementDoc.data() || {};
  const users = suppliedUsers || await loadUsers(db, admin);
  const recipientIds = audienceUserIds(announcement, users);
  let created = 0;
  let failed = 0;

  // Bound concurrent transactions to keep Firestore and Hostinger stable.
  for (let offset = 0; offset < recipientIds.length; offset += 20) {
    const results = await Promise.allSettled(recipientIds.slice(offset, offset + 20).map((userId) =>
      ensureRecipientNotification({ db, admin, announcementId, announcement, userId, now })));
    created += results.filter((result) => result.status === 'fulfilled' && result.value === true).length;
    for (const result of results) {
      if (result.status !== 'rejected') continue;
      failed++;
      console.warn(`Announcement ${announcementId} recipient failed:`, result.reason?.message || result.reason);
    }
  }

  await announcementDoc.ref.set({
    fanoutVersion: 2,
    fanoutStatus: failed === 0 ? 'completed' : 'partial',
    fanoutRecipientCount: recipientIds.length,
    fanoutCreatedCount: created,
    fanoutMissingCount: failed,
    ...(failed === 0 ? {
      fanoutCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
    } : {}),
  }, { merge: true });
  return { announcementId, recipients: recipientIds.length, created, failed };
}

async function reconcileRecentAnnouncements({ db, admin, limit = 50, now = new Date() }) {
  const snapshot = await db.collection('announcements')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();
  const results = [];
  const users = await loadUsers(db, admin);
  for (const announcementDoc of snapshot.docs) {
    const data = announcementDoc.data() || {};
    if (data.fanoutVersion === 2 && data.fanoutCompletedAt) continue;
    results.push(await reconcileAnnouncement({
      db, admin, announcementDoc, now, users,
    }));
  }
  return results;
}

function watchAnnouncements({ db, admin, onReconciled, onError, delayMs = 5000 }) {
  const startedAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 1000));
  return db.collection('announcements')
    .where('createdAt', '>=', startedAt)
    .orderBy('createdAt')
    .limit(100)
    .onSnapshot((snapshot) => {
      for (const change of snapshot.docChanges()) {
        if (change.type !== 'added') continue;
        const run = (attempt = 0) => setTimeout(() => {
          void reconcileAnnouncement({ db, admin, announcementDoc: change.doc })
            .then((result) => {
              onReconciled?.(result);
              if (result.failed > 0 && attempt < 2) run(attempt + 1);
            })
            .catch((error) => onError?.(error));
        }, attempt === 0 ? delayMs : 30 * 1000);
        run();
      }
    }, (error) => onError?.(error));
}

module.exports = {
  DEFAULT_PUSH_MAX_AGE_MINUTES,
  timestampDate,
  isActiveUser,
  audienceUserIds,
  notificationId,
  pushExpiryDate,
  buildNotification,
  reconcileAnnouncement,
  reconcileRecentAnnouncements,
  watchAnnouncements,
};
