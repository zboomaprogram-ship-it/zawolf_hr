const test = require('node:test');
const assert = require('node:assert/strict');
const {
  resolveCheckInStatus,
  submitAttendanceAction,
  resetAttendanceDevice,
} = require('../attendance-gateway');

function fakeAdmin(initialDocs = {}) {
  const docs = new Map(Object.entries(initialDocs));
  const doc = (path) => ({
    async get() {
      const value = docs.get(path);
      if (path.startsWith('users/')) {
        return {
          exists: true,
          data: () => ({
            employeeId: 'EMP-TEST',
            displayName: 'موظف تجريبي',
            ...(value || {}),
          }),
        };
      }
      return { exists: value != null, data: () => value };
    },
    async create(value) {
      if (docs.has(path)) throw new Error('already exists');
      docs.set(path, value);
    },
    async update(value) {
      docs.set(path, { ...(docs.get(path) || {}), ...value });
    },
  });
  const db = {
    collection(name) {
      return { doc: (id) => doc(`${name}/${id}`) };
    },
    async runTransaction(callback) {
      return callback({
        get: (reference) => reference.get(),
        set(reference, value, { merge } = {}) {
          const previous = docs.get(reference._path) || {};
          docs.set(reference._path, merge ? { ...previous, ...value } : value);
        },
        delete(reference) {
          docs.delete(reference._path);
        },
      });
    },
  };
  // The small path marker is only used by the transaction fake above.
  const originalCollection = db.collection.bind(db);
  db.collection = (name) => ({
    doc(id) {
      const reference = doc(`${name}/${id}`);
      reference._path = `${name}/${id}`;
      return reference;
    },
  });
  void originalCollection;
  const admin = {
    firestore: Object.assign(() => db, {
      Timestamp: { fromDate: (value) => value },
      GeoPoint: class GeoPoint { constructor(lat, lng) { this.lat = lat; this.lng = lng; } },
      FieldValue: {
        serverTimestamp: () => 'server-timestamp',
        delete: () => '__deleted__',
      },
    }),
  };
  admin.__testDocs = docs;
  return admin;
}

function actionFor(uid) {
  const date = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
  return {
    type: 'checkIn',
    date,
    attendanceId: `${uid}_${date}`,
    eventTime: Date.now(),
    latitude: 30.0444,
    longitude: 31.2357,
    deviceId: `device-${uid}`,
  };
}

test('check-in returns recorded then already_recorded for the same deterministic action', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-1' };
  const action = actionFor(actor.uid);

  const first = await submitAttendanceAction({ admin, actor, rawAction: action });
  const second = await submitAttendanceAction({ admin, actor, rawAction: action });

  assert.deepEqual(first, {
    action: 'check_in', status: 'recorded', attendanceId: action.attendanceId,
  });
  assert.deepEqual(second, {
    action: 'check_in', status: 'already_recorded', attendanceId: action.attendanceId,
  });
});

test('explicit web-anywhere grant saves no fabricated GPS coordinate', async () => {
  const actor = { uid: 'web-anywhere' };
  const admin = fakeAdmin({
    'webAttendanceAccessGrants/web-anywhere': {
      employeeId: actor.uid, scope: 'permanent', status: 'active',
      allowAnyLocation: true, revision: 3,
    },
  });
  const action = { ...actionFor(actor.uid), clientPlatform: 'web', latitude: 0, longitude: 0 };
  const result = await submitAttendanceAction({ admin, actor, rawAction: action });
  const saved = admin.__testDocs.get(`attendance/${action.attendanceId}`);
  assert.equal(result.status, 'recorded');
  assert.equal(saved.webLocationExempt, true);
  assert.equal(saved.webAttendanceGrantRevision, 3);
  assert.equal(saved.checkInLocation, undefined);
  assert.equal(saved.locationName, 'حضور ويب دون موقع');
});

test('an attendance event older than 24 hours is rejected with a terminal stale_event code', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-expired-event' };
  const action = {
    ...actionFor(actor.uid),
    eventTime: Date.now() - 25 * 60 * 60 * 1000,
  };

  await assert.rejects(
    submitAttendanceAction({ admin, actor, rawAction: action }),
    (error) => error.code === 'stale_event',
  );
});

test('a stale replay converges when its deterministic check-in already exists', async () => {
  const actor = { uid: 'employee-stale-replay' };
  const action = {
    ...actionFor(actor.uid),
    eventTime: Date.now() - 25 * 60 * 60 * 1000,
  };
  const admin = fakeAdmin({
    [`attendance/${action.attendanceId}`]: { checkInTime: new Date() },
  });

  const result = await submitAttendanceAction({ admin, actor, rawAction: action });

  assert.deepEqual(result, {
    action: 'check_in', status: 'already_recorded', attendanceId: action.attendanceId,
  });
});

test('a delayed check-in inside the 24-hour window is accepted for HR security review', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-delayed-checkin' };
  const action = {
    ...actionFor(actor.uid),
    eventTime: Date.now() - 4 * 60 * 1000,
  };

  const result = await submitAttendanceAction({ admin, actor, rawAction: action });
  const saved = admin.__testDocs.get(`attendance/${action.attendanceId}`);
  assert.equal(result.status, 'recorded');
  assert.equal(saved.securityReviewStatus, 'pending_hr');
  assert.equal(saved.locationCapturedOffline, true);
});

test('a check-in event within 2 minutes is accepted normally', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-valid-checkin' };
  const action = {
    ...actionFor(actor.uid),
    eventTime: Date.now() - 90 * 1000,
  };

  const result = await submitAttendanceAction({ admin, actor, rawAction: action });
  assert.equal(result.status, 'recorded');
});

test('a device clock seven minutes ahead is normalized to server time and reviewed', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-clock-ahead' };
  const submittedAt = Date.now() + 7 * 60 * 1000;
  const action = { ...actionFor(actor.uid), eventTime: submittedAt };

  const before = Date.now();
  const result = await submitAttendanceAction({ admin, actor, rawAction: action });
  const after = Date.now();
  const saved = admin.__testDocs.get(`attendance/${action.attendanceId}`);

  assert.equal(result.status, 'recorded');
  assert.equal(saved.securityReviewStatus, 'pending_hr');
  assert.equal(saved.eventTimeNormalizedToServer, true);
  assert.ok(saved.checkInTime.getTime() >= before && saved.checkInTime.getTime() <= after);
  assert.equal(saved.clientSubmittedEventTime.getTime(), submittedAt);
  assert.ok(saved.clientClockSkewSeconds >= 419 && saved.clientClockSkewSeconds <= 421);
  assert.ok(saved.locationRiskReasons.includes('client_clock_ahead'));
});

test('a device clock more than fifteen minutes ahead remains rejected', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-clock-invalid' };
  const action = {
    ...actionFor(actor.uid),
    eventTime: Date.now() + 16 * 60 * 1000,
  };

  await assert.rejects(
    submitAttendanceAction({ admin, actor, rawAction: action }),
    (error) => error.code === 'stale_event',
  );
});

test('HR can reset a bound attendance device only with an audit reason', async () => {
  const admin = fakeAdmin({
    'users/employee-reset': {
      registeredAttendanceDeviceId: 'device-reset',
      registeredAttendanceDeviceLabel: 'Old device',
    },
    'attendanceDevices/device-reset': { userId: 'employee-reset' },
  });

  const result = await resetAttendanceDevice({
    admin,
    actor: { uid: 'hr-1', role: 'hr_admin' },
    employeeId: 'employee-reset',
    reason: 'استبدال جهاز الموظف',
  });

  assert.equal(result.status, 'recorded');
  assert.equal(admin.__testDocs.has('attendanceDevices/device-reset'), false);
  assert.equal(
    [...admin.__testDocs.keys()].some((path) => path.startsWith('auditLogs/attendance_device_reset_employee-reset_')),
    true,
  );
});

test('device reset rejects an unauthorized actor and a missing reason', async () => {
  const admin = fakeAdmin({ 'users/employee-reset': {} });
  await assert.rejects(
    resetAttendanceDevice({
      admin,
      actor: { uid: 'employee-1', role: 'employee' },
      employeeId: 'employee-reset',
      reason: 'x',
    }),
    (error) => error.code === 'not_authorized',
  );
  await assert.rejects(
    resetAttendanceDevice({
      admin,
      actor: { uid: 'hr-1', role: 'hr_admin' },
      employeeId: 'employee-reset',
      reason: '',
    }),
    /سبب إعادة الضبط مطلوب/,
  );
});

test('status lookup is actor-owned and reports recorded or not_recorded', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-2' };
  const action = actionFor(actor.uid);

  assert.equal(
    (await resolveCheckInStatus({ admin, actor, attendanceId: action.attendanceId })).status,
    'not_recorded',
  );
  await submitAttendanceAction({ admin, actor, rawAction: action });
  assert.equal(
    (await resolveCheckInStatus({ admin, actor, attendanceId: action.attendanceId })).status,
    'already_recorded',
  );
  await assert.rejects(
    resolveCheckInStatus({ admin, actor, attendanceId: 'different-user_2026-08-20' }),
    /identity is invalid/,
  );
});

test('legacy gateway records a checkout only after the employee has checked in', async () => {
  const admin = fakeAdmin({
    'publicConfig/checkoutPolicy': { enabled: true, revision: 1 },
  });
  const actor = { uid: 'employee-checkout' };
  const checkIn = actionFor(actor.uid);
  const checkOut = { ...checkIn, type: 'checkOut', eventTime: Date.now() };

  await assert.rejects(
    submitAttendanceAction({ admin, actor, rawAction: checkOut }),
    /سجل الحضور غير موجود بعد/,
  );

  await submitAttendanceAction({ admin, actor, rawAction: checkIn });
  const result = await submitAttendanceAction({ admin, actor, rawAction: checkOut });

  assert.deepEqual(result, {
    action: 'check_out', status: 'recorded', attendanceId: checkIn.attendanceId,
  });
});

test('early checkout stores immutable request evidence and converges on retry', async () => {
  const actor = { uid: 'employee-early' };
  const now = new Date();
  const cairo = Object.fromEntries(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Cairo', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(now).map((part) => [part.type, part.value]));
  const endMinutes = (Number(cairo.hour) * 60 + Number(cairo.minute) + 30) % (24 * 60);
  const endTime = `${String(Math.floor(endMinutes / 60)).padStart(2, '0')}:${String(endMinutes % 60).padStart(2, '0')}`;
  const date = actionFor(actor.uid).date;
  const admin = fakeAdmin({
    'publicConfig/checkoutPolicy': { enabled: true, revision: 1 },
    'publicConfig/appSecurity': {
      pending_early_leave_checkout_v1: { enabled: true, everyone: true },
    },
    'users/employee-early': { workSchedule: { endTime } },
    'permissions/perm-early': {
      userId: actor.uid, permissionType: 'early_leave', requestDate: date,
      durationMinutes: 60, status: 'pending_manager',
    },
  });
  const checkIn = actionFor(actor.uid);
  await submitAttendanceAction({ admin, actor, rawAction: checkIn });
  const checkOut = {
    ...checkIn, type: 'checkOut', eventTime: now.getTime(),
    id: 'checkout-event-1', earlyLeavePermissionId: 'perm-early',
  };
  const first = await submitAttendanceAction({ admin, actor, rawAction: checkOut });
  const second = await submitAttendanceAction({ admin, actor, rawAction: checkOut });
  assert.equal(first.status, 'recorded');
  assert.equal(second.status, 'already_recorded');
  const evidence = admin.__testDocs.get(`attendance/${checkIn.attendanceId}`).earlyLeaveCheckoutEvidence;
  assert.equal(evidence.permissionId, 'perm-early');
  assert.equal(evidence.checkoutEventId, 'checkout-event-1');
  assert.equal(evidence.potentialDayFraction, 0.25);
  assert.equal(
    admin.__testDocs.get('permissions/perm-early').rejectionConsequence.reconciliationState,
    'pending',
  );
});

test('checkout policy is enforced by the gateway before any attendance write', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'employee-policy-disabled' };
  const checkOut = { ...actionFor(actor.uid), type: 'checkOut' };

  const result = await submitAttendanceAction({ admin, actor, rawAction: checkOut });

  assert.equal(result.status, 'checkout_disabled');
  assert.equal(result.action, 'check_out');
  assert.match(result.messageAr, /غير مفعّل/);
  assert.equal(
    [...admin.__testDocs.keys()].some((path) => path.startsWith('attendanceDevices/')),
    false,
  );
  assert.equal(
    [...admin.__testDocs.keys()].some((path) => path.startsWith('attendance/')),
    false,
  );
});

test('multi-location check-in validates an assigned site and stores server evidence', async () => {
  const actor = { uid: 'employee-multi' };
  const admin = fakeAdmin({
    'publicConfig/appSecurity': { attendance_multi_location_v1: true },
    'attendanceLocationAssignments/employee-multi_branch-b': {
      employeeUid: actor.uid,
      locationId: 'branch-b',
      status: 'active',
      version: 2,
      effectiveFrom: new Date(Date.now() - 60_000),
    },
    'locations/branch-b': {
      name: 'فرع ب', latitude: 30.0444, longitude: 31.2357,
      geofenceRadiusMeters: 60, isActive: true,
    },
  });
  const action = {
    ...actionFor(actor.uid),
    locationId: 'branch-b',
    assignmentId: 'employee-multi_branch-b',
    assignmentVersion: 2,
    accuracyMeters: 5,
    distanceMeters: 9999,
    allowedRadius: 9999,
  };

  const result = await submitAttendanceAction({ admin, actor, rawAction: action });
  const saved = admin.__testDocs.get(`attendance/${action.attendanceId}`);

  assert.equal(result.status, 'recorded');
  assert.equal(saved.locationId, 'branch-b');
  assert.equal(saved.locationName, 'فرع ب');
  assert.equal(saved.attendanceLocationAssignmentId, 'employee-multi_branch-b');
  assert.equal(saved.attendanceLocationAssignmentVersion, 2);
  assert.ok(saved.locationDistanceMeters < 1);
  assert.equal(saved.locationAllowedRadiusMeters, 65);
});

test('multi-location rejects stale assignment and forged outside-range evidence', async () => {
  const actor = { uid: 'employee-secure' };
  const initial = {
    'publicConfig/appSecurity': { attendance_multi_location_v1: true },
    'attendanceLocationAssignments/employee-secure_branch-a': {
      employeeUid: actor.uid, locationId: 'branch-a', status: 'active', version: 4,
    },
    'locations/branch-a': {
      name: 'فرع أ', latitude: 30, longitude: 31,
      geofenceRadiusMeters: 50, isActive: true,
    },
  };
  const staleAdmin = fakeAdmin(initial);
  await assert.rejects(
    submitAttendanceAction({
      admin: staleAdmin,
      actor,
      rawAction: {
        ...actionFor(actor.uid), locationId: 'branch-a',
        assignmentId: 'employee-secure_branch-a', assignmentVersion: 3,
        accuracyMeters: 5,
      },
    }),
    (error) => error.code === 'assignment_changed' && /حدّث/.test(error.message),
  );

  const outsideAdmin = fakeAdmin(initial);
  await assert.rejects(
    submitAttendanceAction({
      admin: outsideAdmin,
      actor,
      rawAction: {
        ...actionFor(actor.uid), locationId: 'branch-a',
        assignmentId: 'employee-secure_branch-a', assignmentVersion: 4,
        latitude: 31, longitude: 32, accuracyMeters: 5,
        distanceMeters: 0, allowedRadius: 999999,
      },
    }),
    (error) => error.code === 'outside_range',
  );
});

test('successful duplicate converges after assignment removal', async () => {
  const actor = { uid: 'employee-race' };
  const admin = fakeAdmin({
    'publicConfig/appSecurity': { attendance_multi_location_v1: true },
    'attendanceLocationAssignments/employee-race_branch-a': {
      employeeUid: actor.uid, locationId: 'branch-a', status: 'active', version: 1,
    },
    'locations/branch-a': {
      name: 'فرع أ', latitude: 30.0444, longitude: 31.2357,
      geofenceRadiusMeters: 50, isActive: true,
    },
  });
  const action = {
    ...actionFor(actor.uid), locationId: 'branch-a',
    assignmentId: 'employee-race_branch-a', assignmentVersion: 1,
    accuracyMeters: 5,
  };
  await submitAttendanceAction({ admin, actor, rawAction: action });
  admin.__testDocs.delete('attendanceLocationAssignments/employee-race_branch-a');

  const duplicate = await submitAttendanceAction({ admin, actor, rawAction: action });
  assert.equal(duplicate.status, 'already_recorded');
});
