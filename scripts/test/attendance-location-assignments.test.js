'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  previewAssignments,
  applyAssignments,
  validateAssignedLocation,
} = require('../attendance-location-assignments');

function fakeAdmin(initial = {}) {
  const docs = new Map(Object.entries(initial));
  let reads = 0;
  const db = {
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            path,
            async get() {
              reads += 1;
              const value = docs.get(path);
              return { exists: value != null, data: () => value };
            },
          };
        },
      };
    },
    batch() {
      const writes = [];
      return {
        set(ref, value, options) { writes.push({ ref, value, options }); },
        async commit() {
          for (const write of writes) {
            docs.set(write.ref.path, {
              ...(write.options?.merge ? docs.get(write.ref.path) || {} : {}),
              ...write.value,
            });
          }
        },
      };
    },
  };
  const admin = {
    firestore: Object.assign(() => db, {
      Timestamp: { fromDate: (value) => value },
      FieldValue: {
        serverTimestamp: () => 'server-time',
        increment: (value) => ({ increment: value }),
      },
    }),
    __docs: docs,
    __reads: () => reads,
  };
  return admin;
}

const manager = { uid: 'hr-1', role: 'hr', capabilities: [] };

test('employee cannot preview or apply attendance-location assignments', async () => {
  await assert.rejects(
    previewAssignments({
      admin: fakeAdmin(),
      actor: { uid: 'e1', role: 'employee' },
      raw: { employeeUids: ['e1'], locationIds: ['l1'] },
    }),
    (error) => error.code === 'not_authorized',
  );
});

test('HR preview is bounded and apply is idempotent with audit receipt', async () => {
  const admin = fakeAdmin({
    'users/e1': { isActive: true },
    'locations/l1': {
      name: 'المقر', isActive: true, latitude: 30, longitude: 31,
      geofenceRadiusMeters: 80,
    },
    'locations/l2': {
      name: 'الفرع', isActive: true, latitude: 30.1, longitude: 31.1,
      geofenceRadiusMeters: 60,
    },
  });
  const raw = {
    employeeUids: ['e1'],
    locationIds: ['l1', 'l2'],
    defaultLocationId: 'l1',
    effectiveFrom: '2026-08-24T00:00:00.000Z',
  };
  const preview = await previewAssignments({ admin, actor: manager, raw });
  assert.equal(preview.assignmentCount, 2);
  assert.equal(admin.__reads(), 3);

  const applied = await applyAssignments({
    admin,
    actor: manager,
    raw: { ...raw, operationId: 'assign-001', previewToken: preview.previewToken },
  });
  const retry = await applyAssignments({
    admin,
    actor: manager,
    raw: { ...raw, operationId: 'assign-001', previewToken: preview.previewToken },
  });
  assert.equal(applied.operationId, 'assign-001');
  assert.equal(retry.operationId, 'assign-001');
  assert.ok(admin.__docs.has('attendanceLocationAssignments/e1_l1'));
  assert.ok(admin.__docs.has('attendanceLocationAssignments/e1_l2'));
  assert.ok(admin.__docs.has('auditLogs/attendance_location_assign-001'));
  assert.equal(admin.__docs.get('users/e1').locationId, 'l1');
});

test('server rejects stale assignment versions before attendance write', async () => {
  const admin = fakeAdmin({
    'attendanceLocationAssignments/e1_l1': {
      employeeUid: 'e1', locationId: 'l1', status: 'active', version: 4,
    },
    'locations/l1': {
      name: 'المقر', isActive: true, latitude: 30, longitude: 31,
      geofenceRadiusMeters: 80,
    },
  });
  await assert.rejects(
    validateAssignedLocation({
      db: admin.firestore(),
      actorUid: 'e1',
      eventTime: new Date('2026-08-24T08:00:00Z'),
      rawAction: {
        locationId: 'l1', assignmentId: 'e1_l1', assignmentVersion: 3,
        latitude: 30, longitude: 31, accuracyMeters: 5,
      },
    }),
    (error) => error.code === 'assignment_changed',
  );
});

test('HR removal is explicit, idempotent, audited, and keeps history', async () => {
  const admin = fakeAdmin({
    'users/e1': { isActive: true },
    'locations/l1': { name: 'المقر', isActive: true },
    'attendanceLocationAssignments/e1_l1': {
      employeeUid: 'e1', locationId: 'l1', status: 'active', isActive: true,
      version: 3, createdAt: 'old-created-at',
    },
  });
  const raw = {
    mode: 'remove', employeeUids: ['e1'], locationIds: ['l1'],
    effectiveFrom: '2026-08-24T12:00:00.000Z',
  };
  const preview = await previewAssignments({ admin, actor: manager, raw });
  assert.equal(preview.mode, 'remove');
  const applied = await applyAssignments({
    admin, actor: manager,
    raw: { ...raw, operationId: 'remove-001', previewToken: preview.previewToken },
  });
  const retry = await applyAssignments({
    admin, actor: manager,
    raw: { ...raw, operationId: 'remove-001', previewToken: preview.previewToken },
  });
  const assignment = admin.__docs.get('attendanceLocationAssignments/e1_l1');
  assert.equal(applied.mode, 'remove');
  assert.equal(retry.operationId, applied.operationId);
  assert.equal(assignment.status, 'inactive');
  assert.equal(assignment.isActive, false);
  assert.equal(assignment.createdAt, 'old-created-at');
  assert.equal(
    admin.__docs.get('auditLogs/attendance_location_remove-001').action,
    'attendance_location_assignments_removed',
  );
});

test('bulk preview refuses operations that cannot fit in one atomic batch', async () => {
  const employees = Array.from({ length: 100 }, (_, index) => `e${index}`);
  const locations = Array.from({ length: 5 }, (_, index) => `l${index}`);
  const admin = fakeAdmin();
  await assert.rejects(
    previewAssignments({
      admin, actor: manager,
      raw: { employeeUids: employees, locationIds: locations },
    }),
    (error) => error.code === 'capacity_reached',
  );
  assert.equal(admin.__reads(), 0);
});
