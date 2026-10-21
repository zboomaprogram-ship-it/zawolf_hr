'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  recordManualAttendance,
  listManualAttendanceEmployees,
  cairoParts,
} = require('../manual-attendance');

function createMockDb({
  userExists = true,
  isActive = true,
  workDays = [1, 2, 3, 4, 6, 7], // Mon-Thu, Sat, Sun
  companyDayOff = false,
  leaveExists = false,
  attendanceData = null,
  cycleFinalized = false,
} = {}) {
  const store = {
    users: {
      'employee-12345678': {
        displayName: 'أحمد علي',
        employeeId: 'EMP001',
        department: 'الهندسة',
        email: 'ahmed@example.com',
        isActive,
        workSchedule: { workDays },
      },
    },
    companyDayOffs: {
      '2026-10-15': { isActive: companyDayOff },
    },
    leaves: leaveExists ? [{ status: 'approved', startDate: new Date('2026-10-15T00:00:00Z'), endDate: new Date('2026-10-15T23:59:59Z') }] : [],
    attendance: {},
    attendanceManualOperations: {},
    auditLogs: {},
    payrollCycles: {
      '2026-10': { status: cycleFinalized ? 'finalized' : 'draft' },
      '2026-09': { status: 'finalized' },
    },
  };
  if (attendanceData) {
    store.attendance['employee-12345678_2026-10-15'] = attendanceData;
  }

  const mockAdmin = {
    firestore: {
      Timestamp: {
        fromDate: (d) => ({ toDate: () => d, seconds: Math.floor(d.getTime() / 1000) }),
      },
      FieldValue: {
        serverTimestamp: () => new Date(),
        increment: (n) => n,
      },
    },
  };

  const db = {
    collection: (coll) => ({
      doc: (id) => ({
        get: async () => ({
          exists: Boolean(store[coll]?.[id]),
          data: () => store[coll]?.[id],
        }),
        collection: (subColl) => ({
          doc: (subId) => ({
            get: async () => ({ exists: false }),
            set: async () => {},
          }),
        }),
      }),
      where: (field, op, val) => ({
        get: async () => ({
          docs: (store[coll] || []).map((data) => ({
            data: () => data,
          })),
        }),
        limit: (n) => ({
          get: async () => ({
            docs: Object.entries(store.users || {}).map(([id, user]) => ({
              id,
              data: () => user,
            })),
          }),
        }),
      }),
    }),
    runTransaction: async (fn) => {
      const tx = {
        get: async (ref) => ref.get(),
        set: (ref, data, opts) => {},
      };
      return fn(tx);
    },
  };

  return { db, admin: mockAdmin };
}

test('recordManualAttendance rejects future date/time', async () => {
  const { db, admin } = createMockDb();
  const future = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
  await assert.rejects(
    () => recordManualAttendance({
      db,
      admin,
      actor: { uid: 'hr1', role: 'hr' },
      body: {
        operationId: 'op12345678',
        employeeId: 'employee-12345678',
        eventType: 'checkIn',
        effectiveAt: future.toISOString(),
        reason: 'تسجيل مستقبلي خاطئ',
      },
    }),
    /لا يمكن تسجيل حضور في تاريخ أو وقت مستقبلي/
  );
});

test('recordManualAttendance rejects finalized payroll cycles', async () => {
  const { db, admin } = createMockDb({ cycleFinalized: true });
  // Cycle for 2026-10-15 ends 2026-10-25 -> cycleKey '2026-10'
  const pastInClosedCycle = new Date('2026-10-15T09:00:00Z');
  await assert.rejects(
    () => recordManualAttendance({
      db,
      admin,
      actor: { uid: 'hr1', role: 'hr' },
      body: {
        operationId: 'op12345678',
        employeeId: 'employee-12345678',
        eventType: 'checkIn',
        effectiveAt: pastInClosedCycle.toISOString(),
        reason: 'تسجيل في دورة مغلقة',
      },
    }),
    /لا يمكن تعديل حضور في دورة رواتب مغلقة/
  );
});

test('recordManualAttendance accepts past date in open payroll cycle', async () => {
  const { db, admin } = createMockDb({ cycleFinalized: false });
  // 2026-10-15 is Thursday (weekday Thu = workDay 4)
  const pastInOpenCycle = new Date('2026-10-15T09:00:00Z');
  const result = await recordManualAttendance({
    db,
    admin,
    actor: { uid: 'hr1', role: 'hr' },
    body: {
      operationId: 'op12345678',
      employeeId: 'employee-12345678',
      eventType: 'checkIn',
      effectiveAt: pastInOpenCycle.toISOString(),
      reason: 'نسيان كارت الحضور في موقع العمل',
    },
  });
  assert.equal(result.status, 'recorded');
  assert.equal(result.attendanceId, 'employee-12345678_2026-10-15');
});

test('listManualAttendanceEmployees filters by past date', async () => {
  const { db } = createMockDb({
    attendanceData: {
      checkInTime: { toDate: () => new Date('2026-10-15T08:30:00Z') },
      checkOutTime: { toDate: () => new Date('2026-10-15T16:30:00Z') },
    },
  });
  const employees = await listManualAttendanceEmployees({
    db,
    actor: { uid: 'hr1', role: 'hr' },
    query: 'أحمد',
    date: '2026-10-15',
  });
  assert.equal(employees.length, 1);
  assert.equal(employees[0].isCheckedIn, true);
  assert.equal(employees[0].isCheckedOut, true);
});
