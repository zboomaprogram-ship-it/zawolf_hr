'use strict';

const crypto = require('node:crypto');
const { buildMigrationPlan } = require('./migrate-organization-structure');

const DEFAULT_TREE_ID = 'organization-default';

function membershipId(treeId, employeeUid, unitId) {
  return `${treeId}_${employeeUid}_${unitId}`;
}

function buildMultiTreeMigrationPlan({ units = [], users = [], existingTrees = [], existingMemberships = [], defaultTreeId = null }) {
  const selectedTreeId = String(defaultTreeId || '').trim() || DEFAULT_TREE_ID;
  const tree = existingTrees.find((item) => item.id === selectedTreeId) || {
    id: selectedTreeId,
    name: 'الهيكل الرئيسي',
    purpose: 'هيكل التوافق مع النظام الحالي',
    status: 'active',
    isDefault: true,
    order: 0,
    version: 1,
  };
  const existingIds = new Set(existingMemberships.map((item) => item.id));
  const unitWrites = units
    .filter((unit) => !unit.treeId)
    .map((unit) => ({ id: unit.id, value: { treeId: selectedTreeId, multiTreeMigrationVersion: 1 } }));
  const membershipWrites = [];
  const userWrites = [];
  for (const user of users) {
    const employeeUid = String(user.uid || user.id || '').trim();
    const unitId = String(user.departmentUnitId || user.departmentId || '').trim();
    if (!employeeUid || !unitId || user.isActive === false) continue;
    const id = membershipId(selectedTreeId, employeeUid, unitId);
    if (!existingIds.has(id)) {
      membershipWrites.push({ id, value: {
        id,
        treeId: selectedTreeId,
        employeeUid,
        unitId,
        directManagerUid: user.directManagerId || user.managerId || null,
        isPrimary: true,
        status: 'active',
        version: 1,
        multiTreeMigrationVersion: 1,
      } });
    }
    if (user.primaryOrganizationMembershipId !== id) {
      userWrites.push({ id: employeeUid, value: {
        primaryOrganizationTreeId: selectedTreeId,
        primaryOrganizationMembershipId: id,
        multiTreeMigrationVersion: 1,
      } });
    }
  }
  const fingerprint = crypto.createHash('sha256').update(JSON.stringify({
    tree: tree.id,
    units: unitWrites.map((write) => write.id).sort(),
    memberships: membershipWrites.map((write) => write.id).sort(),
    users: userWrites.map((write) => write.id).sort(),
  })).digest('hex');
  return {
    dryRun: true,
    treeWrite: existingTrees.some((item) => item.id === selectedTreeId) ? null : { id: tree.id, value: tree },
    unitWrites,
    membershipWrites,
    userWrites,
    fingerprint,
    summary: { trees: existingTrees.some((item) => item.id === selectedTreeId) ? 0 : 1, units: unitWrites.length, memberships: membershipWrites.length, users: userWrites.length },
    rollback: { mode: 'disable_flag', flag: 'company_os_multi_tree_v1', destructiveWrites: 0 },
  };
}

async function applyMultiTreeMigration({ db, plan, approvedFingerprint }) {
  if (!plan || plan.fingerprint !== approvedFingerprint) {
    const error = new Error('Migration fingerprint is not approved');
    error.code = 'access_denied';
    throw error;
  }
  const writes = [
    ...(plan.treeWrite ? [{ collection: 'companyOsOrganizationTrees', ...plan.treeWrite }] : []),
    ...plan.unitWrites.map((write) => ({ collection: 'companyOsOrganizationUnits', ...write })),
    ...plan.membershipWrites.map((write) => ({ collection: 'companyOsOrganizationMemberships', ...write })),
    ...plan.userWrites.map((write) => ({ collection: 'users', ...write })),
  ];
  for (let offset = 0; offset < writes.length; offset += 400) {
    const batch = db.batch();
    for (const write of writes.slice(offset, offset + 400)) {
      batch.set(db.collection(write.collection).doc(write.id), write.value, { merge: true });
    }
    await batch.commit();
  }
  return { ...plan, dryRun: false, applied: true };
}

// Produces one additive plan for installations that still keep their hierarchy
// in the legacy collections.  It is deliberately preview-first: no legacy
// record is removed and the caller must echo the exact fingerprint to apply.
function buildOrganizationTreeBootstrapPlan({
  divisions = [], departments = [], users = [], existingUnits = [], existingTrees = [], existingMemberships = [],
}) {
  const legacy = buildMigrationPlan({ divisions, departments, users });
  const knownUnits = new Map(existingUnits.map((unit) => [unit.id, unit]));
  const canonicalUnits = existingUnits.length ? existingUnits : legacy.units;
  const legacyUnitWrites = existingUnits.length
    ? []
    : legacy.units.filter((unit) => !knownUnits.has(unit.id)).map((unit) => ({ id: unit.id, value: unit }));
  const membershipByEmployee = new Map(
    legacy.memberships.filter((item) => item.departmentUnitId).map((item) => [item.uid, item]),
  );
  const projectedUsers = users.map((user) => {
    const uid = String(user.uid || user.id || '').trim();
    const legacyMembership = membershipByEmployee.get(uid);
    return legacyMembership && !user.departmentUnitId
      ? { ...user, departmentUnitId: legacyMembership.departmentUnitId, directManagerId: legacyMembership.directManagerId }
      : user;
  });
  const existingTargetTree = existingTrees.find((tree) => tree.isDefault === true && tree.status !== 'archived')
    || existingTrees.find((tree) => tree.status !== 'archived')
    || null;
  const treePlan = buildMultiTreeMigrationPlan({
    units: canonicalUnits,
    users: projectedUsers,
    existingTrees,
    existingMemberships,
    defaultTreeId: existingTargetTree?.id || DEFAULT_TREE_ID,
  });
  const fingerprint = crypto.createHash('sha256').update(JSON.stringify({
    legacyUnits: legacyUnitWrites.map((write) => write.id).sort(),
    tree: treePlan.treeWrite?.id || null,
    units: treePlan.unitWrites.map((write) => write.id).sort(),
    memberships: treePlan.membershipWrites.map((write) => write.id).sort(),
    users: treePlan.userWrites.map((write) => write.id).sort(),
  })).digest('hex');
  return {
    ...treePlan,
    fingerprint,
    legacyUnitWrites,
    legacyIssues: legacy.issues,
    summary: {
      ...treePlan.summary,
      legacyUnits: legacyUnitWrites.length,
      legacyIssues: legacy.issues.length,
    },
    rollback: { mode: 'disable_flag', flag: 'company_os_multi_tree_v1', destructiveWrites: 0 },
  };
}

async function applyOrganizationTreeBootstrap({ db, plan, approvedFingerprint }) {
  if (!plan || plan.fingerprint !== approvedFingerprint) {
    const error = new Error('Migration fingerprint is not approved');
    error.code = 'access_denied';
    throw error;
  }
  const writes = [
    ...plan.legacyUnitWrites.map((write) => ({ collection: 'companyOsOrganizationUnits', ...write })),
    ...(plan.treeWrite ? [{ collection: 'companyOsOrganizationTrees', ...plan.treeWrite }] : []),
    ...plan.unitWrites.map((write) => ({ collection: 'companyOsOrganizationUnits', ...write })),
    ...plan.membershipWrites.map((write) => ({ collection: 'companyOsOrganizationMemberships', ...write })),
    ...plan.userWrites.map((write) => ({ collection: 'users', ...write })),
  ];
  for (let offset = 0; offset < writes.length; offset += 400) {
    const batch = db.batch();
    for (const write of writes.slice(offset, offset + 400)) {
      batch.set(db.collection(write.collection).doc(write.id), write.value, { merge: true });
    }
    await batch.commit();
  }
  return { ...plan, dryRun: false, applied: true };
}

module.exports = {
  DEFAULT_TREE_ID,
  membershipId,
  buildMultiTreeMigrationPlan,
  applyMultiTreeMigration,
  buildOrganizationTreeBootstrapPlan,
  applyOrganizationTreeBootstrap,
};
