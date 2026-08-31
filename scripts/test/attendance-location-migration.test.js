'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildAttendanceLocationMigrationPlan } = require('../migrate-attendance-locations');

test('legacy location migration is deterministic, additive, and reversible by flag', () => {
  const input = {
    users: [
      { id: 'u2', locationId: 'b', locationName: 'B', isActive: true },
      { id: 'u1', locationId: 'a', locationName: 'A', isActive: true },
      { id: 'disabled', locationId: 'a', isActive: false },
    ],
  };
  const first = buildAttendanceLocationMigrationPlan(input);
  const second = buildAttendanceLocationMigrationPlan(input);
  assert.equal(first.fingerprint, second.fingerprint);
  assert.deepEqual(first.writes.map((item) => item.id), ['u1_a', 'u2_b']);
  assert.equal(first.rollback.destructiveWrites, 0);

  const converged = buildAttendanceLocationMigrationPlan({
    ...input,
    existingAssignments: first.writes.map((write) => ({ id: write.id })),
  });
  assert.equal(converged.summary.assignments, 0);
});
