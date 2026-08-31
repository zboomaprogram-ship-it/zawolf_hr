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

test('attendance-request-gateway: idempotent check-in returns recorded then already_recorded', async () => {
  const admin = fakeAdmin();
  const actor = { uid: 'emp-req-1' };
  const action = actionFor(actor.uid);

  const res1 = await submitAttendanceAction({ admin, actor, rawAction: action });
  assert.equal(res1.status, 'recorded');

  const res2 = await submitAttendanceAction({ admin, actor, rawAction: action });
  assert.equal(res2.status, 'already_recorded');
});

test('attendance-request-gateway: authorized device reset requires reason and hr_admin or admin role', async () => {
  const admin = fakeAdmin({
    'users/emp-reset-1': { registeredAttendanceDeviceId: 'dev-1' },
    'attendanceDevices/dev-1': { userId: 'emp-reset-1' },
  });

  await assert.rejects(
    resetAttendanceDevice({
      admin,
      actor: { uid: 'emp-1', role: 'employee' },
      employeeId: 'emp-reset-1',
      reason: 'reset request',
    }),
    (err) => err.code === 'not_authorized',
  );

  const res = await resetAttendanceDevice({
    admin,
    actor: { uid: 'hr-1', role: 'hr_admin' },
    employeeId: 'emp-reset-1',
    reason: 'جهاز جديد للموظف',
  });
  assert.equal(res.status, 'recorded');
});
