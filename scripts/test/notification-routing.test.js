const test = require('node:test');
const assert = require('node:assert/strict');

const {
  routeForNotification,
  isUnsubscribedDeviceError,
} = require('../dispatch-notifications');
const { isWorkDay, notificationFor } = require('../attendance-reminders');
const { parseFirebaseServiceAccount } = require('../firebase-service-account');
const { deductionFor, effectiveTimes, haversineMeters } = require('../auto-attendance');
const { getExistingFirebaseApp } = require('../firebase-service-account');
const { installFirestoreCompatibility } = require('../firebase-service-account');
const admin = require('firebase-admin');

test('request and task notifications open the intended app areas', () => {
  assert.equal(routeForNotification('permission_pending_hr'), '/manager/requests');
  assert.equal(routeForNotification('leave_approved'), '/employee/requests');
  assert.equal(routeForNotification('task_assigned'), '/employee/tasks');
  assert.equal(
    routeForNotification('salary_deduction_reviewed'),
    '/employee/dashboard',
  );
});

test('unsubscribed OneSignal devices wait without exhausting delivery attempts', () => {
  assert.equal(
    isUnsubscribedDeviceError(
      new Error('OneSignal push returned errors: ["All included players are not subscribed"]'),
    ),
    true,
  );
  assert.equal(isUnsubscribedDeviceError(new Error('Network unavailable')), false);
});

test('attendance reminders follow work days and approved permission times', () => {
  assert.equal(isWorkDay({}, 'Fri'), false);
  assert.equal(isWorkDay({ workSchedule: { workDays: [6] } }, 'Sat'), true);

  const checkInBefore = notificationFor({
    kind: 'check_in_before',
    startMinutes: 11 * 60,
    endMinutes: 17 * 60,
    hasLatePermission: true,
    hasEarlyPermission: false,
  });
  const checkInStart = notificationFor({
    kind: 'check_in_start',
    startMinutes: 11 * 60,
    endMinutes: 17 * 60,
    hasLatePermission: true,
    hasEarlyPermission: false,
  });
  const lateWarning = notificationFor({
    kind: 'check_in_late_warning',
    startMinutes: 11 * 60,
    endMinutes: 17 * 60,
    hasLatePermission: true,
    hasEarlyPermission: false,
  });
  const checkOut = notificationFor({
    kind: 'check_out',
    startMinutes: 9 * 60,
    endMinutes: 15 * 60,
    hasLatePermission: false,
    hasEarlyPermission: true,
  });

  assert.equal(checkInBefore.targetMinutes, 10 * 60 + 50);
  assert.match(checkInBefore.body, /11:00/);
  assert.equal(checkInStart.targetMinutes, 11 * 60);
  assert.equal(lateWarning.targetMinutes, 11 * 60 + 10);
  assert.equal(checkOut.targetMinutes, 15 * 60);
  assert.match(checkOut.body, /15:00/);
});

test('normalizes Hostinger escaped Firebase service-account JSON', () => {
  const original = {
    project_id: 'zawolf-hr-system-60317',
    client_email: 'service@example.com',
    private_key: 'line-one\\nline-two',
  };
  const hostingerValue = `\\${JSON.stringify(original).replace(/"/g, '\\"')}`;

  const parsed = parseFirebaseServiceAccount(hostingerValue);
  assert.equal(parsed.project_id, original.project_id);
  assert.equal(parsed.client_email, original.client_email);
  assert.match(parsed.private_key, /line-one\nline-two/);
});

test('supports the Firebase Admin v14 app registry API', () => {
  const app = { name: 'default' };
  assert.equal(getExistingFirebaseApp({ getApps: () => [app] }), app);
  assert.equal(getExistingFirebaseApp({ getApps: () => [] }), null);
});

test('uses the Firebase Admin v14 certificate factory', () => {
  assert.equal(typeof admin.cert, 'function');
  assert.equal(typeof admin.credential, 'undefined');
});

test('installs Firestore compatibility for Firebase Admin v14', () => {
  const fakeAdmin = {};
  installFirestoreCompatibility(fakeAdmin);
  assert.equal(typeof fakeAdmin.firestore, 'function');
  assert.equal(typeof fakeAdmin.firestore.FieldValue, 'function');
  assert.equal(typeof fakeAdmin.firestore.Timestamp, 'function');
});

test('automatic attendance uses approved permission times and the salary policy', () => {
  const times = effectiveTimes(
    { workSchedule: { startTime: '09:00', endTime: '17:00' } },
    {},
    [{ permissionType: 'late_arrival', durationMinutes: 120 }],
  );
  assert.equal(times.start, 11 * 60);
  assert.equal(times.end, 17 * 60);
  const deduction = deductionFor(11 * 60 + 16, times.start, {}, 26000, 'EGP');
  assert.equal(deduction.fraction, 0.25);
  assert.equal(deduction.amount, 250);
  assert.ok(haversineMeters(30, 31, 30, 31.0001) < 20);
});
