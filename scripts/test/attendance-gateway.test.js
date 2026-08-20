const test = require('node:test');
const assert = require('node:assert/strict');
const {
  resolveCheckInStatus,
  submitAttendanceAction,
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
      await callback({
        get: (reference) => reference.get(),
        set(reference, value, { merge } = {}) {
          const previous = docs.get(reference._path) || {};
          docs.set(reference._path, merge ? { ...previous, ...value } : value);
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
      FieldValue: { serverTimestamp: () => 'server-timestamp' },
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
