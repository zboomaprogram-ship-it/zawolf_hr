'use strict';

const crypto = require('node:crypto');
const { assignmentId } = require('./attendance-location-assignments');

function buildAttendanceLocationMigrationPlan({ users = [], existingAssignments = [] } = {}) {
  const existingIds = new Set(existingAssignments.map((item) => String(item.id || '')));
  const writes = [];
  for (const user of users) {
    const employeeUid = String(user.uid || user.id || '').trim();
    const locationId = String(user.locationId || '').trim();
    if (!employeeUid || !locationId || user.isActive === false) continue;
    const id = assignmentId(employeeUid, locationId);
    if (existingIds.has(id)) continue;
    writes.push({
      id,
      value: {
        employeeUid,
        locationId,
        locationName: String(user.locationName || ''),
        status: 'active',
        isDefault: true,
        priority: 0,
        version: 1,
        migrationVersion: 1,
      },
    });
  }
  writes.sort((a, b) => a.id.localeCompare(b.id));
  const fingerprint = crypto
    .createHash('sha256')
    .update(JSON.stringify(writes.map((write) => write.id)))
    .digest('hex');
  return {
    dryRun: true,
    writes,
    fingerprint,
    summary: { assignments: writes.length },
    rollback: {
      mode: 'disable_flag',
      flag: 'attendance_multi_location_v1',
      destructiveWrites: 0,
    },
  };
}

async function applyAttendanceLocationMigration({ db, admin, plan, approvedFingerprint }) {
  if (!plan || plan.fingerprint !== approvedFingerprint) {
    const error = new Error('Migration fingerprint is not approved');
    error.code = 'access_denied';
    throw error;
  }
  for (let offset = 0; offset < plan.writes.length; offset += 400) {
    const batch = db.batch();
    for (const write of plan.writes.slice(offset, offset + 400)) {
      batch.set(db.collection('attendanceLocationAssignments').doc(write.id), {
        ...write.value,
        effectiveFrom: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'migration',
        updatedBy: 'migration',
      }, { merge: true });
    }
    await batch.commit();
  }
  return { ...plan, dryRun: false, applied: true };
}

module.exports = {
  buildAttendanceLocationMigrationPlan,
  applyAttendanceLocationMigration,
};
