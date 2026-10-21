'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { firestore } = require('./fixtures/chat-firestore');
const {
  audienceUserIds,
  notificationId,
  buildNotification,
  reconcileAnnouncement,
} = require('../announcement-notification-reconciliation');

const admin = {
  firestore: {
    FieldPath: { documentId: () => '__name__' },
    Timestamp: { fromDate: (date) => date },
    FieldValue: {
      serverTimestamp: () => ({ __serverTimestamp: true }),
      increment: (value) => ({ __increment: value }),
    },
  },
};

test('global audience includes legacy active users and excludes explicitly inactive users', () => {
  const recipients = audienceUserIds(
    { targetGroup: 'all', targetUserIds: ['modern'] },
    [
      { id: 'modern', data: { isActive: true } },
      { id: 'legacy', data: {} },
      { id: 'disabled', data: { isActive: false } },
    ],
  );
  assert.deepEqual(recipients.sort(), ['legacy', 'modern']);
});

test('targeted announcement never widens beyond captured users', () => {
  const recipients = audienceUserIds(
    { targetGroup: 'selected', targetUserIds: ['selected'] },
    [
      { id: 'selected', data: {} },
      { id: 'other', data: {} },
    ],
  );
  assert.deepEqual(recipients, ['selected']);
});

test('notification ids are stable per announcement and recipient', () => {
  assert.equal(notificationId('a1', 'u1'), notificationId('a1', 'u1'));
  assert.notEqual(notificationId('a1', 'u1'), notificationId('a1', 'u2'));
});

test('old announcements remain in notification center without delayed push', () => {
  const now = new Date('2026-10-21T12:00:00Z');
  const notification = buildNotification({
    announcementId: 'old',
    announcement: { title: 'قديم', body: 'خبر', createdAt: new Date('2026-10-20T00:00:00Z') },
    now,
    admin,
  });
  assert.equal(notification.isRead, true);
  assert.equal(notification.pushSent, true);
  assert.equal(notification.pushDeliveryStatus, 'expired');
  assert.equal(notification.createdAt.toISOString(), '2026-10-20T00:00:00.000Z');
});

test('reconciliation creates one deterministic notification per missing active recipient', async () => {
  const db = firestore({
    'users/u1': { displayName: 'One' },
    'users/u2': { displayName: 'Two', isActive: true },
    'users/u3': { displayName: 'Disabled', isActive: false },
    'announcements/a1': {
      targetGroup: 'all', title: 'Title', body: 'Body',
      createdAt: new Date('2026-10-21T11:30:00Z'),
    },
  });
  const announcementDoc = await db.collection('announcements').doc('a1').get();
  const first = await reconcileAnnouncement({
    db, admin, announcementDoc, now: new Date('2026-10-21T12:00:00Z'),
  });
  const secondDoc = await db.collection('announcements').doc('a1').get();
  const second = await reconcileAnnouncement({
    db, admin, announcementDoc: secondDoc, now: new Date('2026-10-21T12:01:00Z'),
  });
  assert.deepEqual(first, { announcementId: 'a1', recipients: 2, created: 2, failed: 0 });
  assert.equal(second.created, 0);
  const dump = db.dump();
  assert.ok(dump[`notifications/u1/items/${notificationId('a1', 'u1')}`]);
  assert.ok(dump[`notifications/u2/items/${notificationId('a1', 'u2')}`]);
  assert.equal(dump[`notifications/u3/items/${notificationId('a1', 'u3')}`], undefined);
});

test('version 1 historical repair is silenced and retains the original announcement date', async () => {
  const id = notificationId('old-a', 'u1');
  const originalDate = new Date('2026-10-01T08:00:00Z');
  const db = firestore({
    'users/u1': { isActive: true, unreadNotifications: 3 },
    'announcements/old-a': {
      targetGroup: 'all', title: 'Old', body: 'Archive', createdAt: originalDate,
      fanoutVersion: 1,
    },
    [`notifications/u1/items/${id}`]: {
      notificationId: id, type: 'hr_announcement', isRead: false,
      pushSent: true, createdAt: new Date('2026-10-21T12:00:00Z'),
      data: { announcementId: 'old-a' },
    },
  });
  const announcementDoc = await db.collection('announcements').doc('old-a').get();
  const result = await reconcileAnnouncement({
    db, admin, announcementDoc, now: new Date('2026-10-21T12:00:00Z'),
  });
  assert.equal(result.created, 0);
  const dump = db.dump();
  assert.equal(dump[`notifications/u1/items/${id}`].isRead, true);
  assert.equal(dump[`notifications/u1/items/${id}`].createdAt.toISOString(), originalDate.toISOString());
  assert.equal(dump['users/u1'].unreadNotifications, 2);
});
