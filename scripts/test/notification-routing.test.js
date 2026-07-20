const test = require('node:test');
const assert = require('node:assert/strict');

const {
  routeForNotification,
  isUnsubscribedDeviceError,
} = require('../dispatch-notifications');
const {
  isWorkDay,
  isReminderScanWindow,
  notificationFor,
  dueReminderPlans,
} = require('../attendance-reminders');
const { parseFirebaseServiceAccount } = require('../firebase-service-account');
const { deductionFor, effectiveTimes, haversineMeters } = require('../auto-attendance');
const { getExistingFirebaseApp } = require('../firebase-service-account');
const { installFirestoreCompatibility } = require('../firebase-service-account');
const admin = require('firebase-admin');

test('request and task notifications open the intended app areas', () => {
  assert.equal(routeForNotification('permission_pending_hr'), '/manager/requests');
  assert.equal(routeForNotification('leave_approved'), '/employee/requests');
  assert.equal(routeForNotification('task_assigned'), '/employee/tasks');
  assert.equal(routeForNotification('poll_created'), '/polls');
  assert.equal(
    routeForNotification('salary_deduction_reviewed'),
    '/employee/dashboard',
  );
});

test('detects unsubscribed OneSignal devices so they are not retried forever', () => {
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
  const finalWarning = notificationFor({
    kind: 'check_in_final_warning',
    startMinutes: 9 * 60,
    endMinutes: 17 * 60,
    hasLatePermission: false,
    hasEarlyPermission: false,
    halfDayUntilMinutes: 25,
    finalWarningLeadMinutes: 5,
  });

  assert.equal(checkInBefore.targetMinutes, 10 * 60 + 50);
  assert.match(checkInBefore.body, /11:00/);
  assert.equal(checkInStart.targetMinutes, 11 * 60);
  assert.equal(lateWarning.targetMinutes, 11 * 60 + 10);
  assert.equal(checkOut.targetMinutes, 15 * 60);
  assert.match(checkOut.body, /15:00/);
  assert.equal(finalWarning.targetMinutes, 9 * 60 + 20);
  assert.match(finalWarning.body, /09:26/);
});

test('a Hostinger cold start queues only the latest relevant morning reminder', () => {
  const plans = [
    { kind: 'check_in_before', notification: { targetMinutes: 8 * 60 + 50 } },
    { kind: 'check_in_start', notification: { targetMinutes: 9 * 60 } },
    { kind: 'check_in_late_warning', notification: { targetMinutes: 9 * 60 + 10 } },
    { kind: 'check_in_final_warning', notification: { targetMinutes: 9 * 60 + 55 } },
    { kind: 'check_out', notification: { targetMinutes: 17 * 60 } },
  ];

  assert.deepEqual(
    dueReminderPlans(plans, 9 * 60 + 36).map((plan) => plan.kind),
    ['check_in_late_warning'],
  );
  assert.deepEqual(
    dueReminderPlans(plans, 17 * 60).map((plan) => plan.kind),
    ['check_out'],
  );
  assert.deepEqual(
    dueReminderPlans(plans, 9 * 60 + 56).map((plan) => plan.kind),
    ['check_in_final_warning'],
  );
});

test('attendance scans do not read employees outside the configured work window', () => {
  assert.equal(isReminderScanWindow(5 * 60 + 55, {}), false);
  assert.equal(isReminderScanWindow(9 * 60, {}), true);
  assert.equal(isReminderScanWindow(20 * 60 + 5, {}), false);
  assert.equal(
    isReminderScanWindow(22 * 60, {
      reminderScanStartTime: '21:00',
      reminderScanEndTime: '02:00',
    }),
    true,
  );
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
