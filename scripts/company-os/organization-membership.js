'use strict';

const { executeOperation } = require('./operation-gateway');
const { requireOrganizationManage } = require('./organization-authorization');

function normalizeEmployeeIds(values) {
  const ids = [...new Set((values || []).map((value) => String(value || '').trim()).filter(Boolean))];
  if (!ids.length || ids.length > 100) { const error = new Error('Invalid employees'); error.code = 'invalid_input'; throw error; }
  return ids;
}

async function previewMembershipChange({ store, actor, employeeUids, destinationDepartmentId = null, directManagerUid = null }) {
  requireOrganizationManage(actor); const ids = normalizeEmployeeIds(employeeUids);
  return store.transact(async (tx) => {
    if (destinationDepartmentId) {
      const unit = await tx.getUnit(destinationDepartmentId);
      if (!unit || unit.type !== 'department' || unit.archived === true) { const error = new Error('Invalid department'); error.code = 'invalid_input'; throw error; }
    }
    if (directManagerUid) {
      const manager = await tx.getUser(directManagerUid);
      if (!manager || manager.isActive !== true) { const error = new Error('Invalid manager'); error.code = 'invalid_input'; throw error; }
    }
    const users = await Promise.all(ids.map((id) => tx.getUser(id)));
    if (users.some((user) => !user || user.isActive !== true)) { const error = new Error('Invalid employee'); error.code = 'invalid_input'; throw error; }
    return { ok: true, dryRun: true, affectedEmployees: ids.length, employeeUids: ids, destinationDepartmentId, directManagerUid, previousDepartments: [...new Set(users.map((u) => u.departmentId).filter(Boolean))] };
  });
}

async function applyMembershipChange({ store, actor, operationId, employeeUids, destinationDepartmentId = null, sourceDepartmentId = null, directManagerUid = null, expectedVersion = null, now = new Date() }) {
  requireOrganizationManage(actor); const ids = normalizeEmployeeIds(employeeUids);
  const versionUnitId = destinationDepartmentId || sourceDepartmentId || null;
  return executeOperation({ store, operationId, actor, operationType: 'organization_membership_change', targetId: versionUnitId || 'unassigned', payload: { employeeUids: ids, destinationDepartmentId, sourceDepartmentId, directManagerUid }, expectedVersion,
    currentVersion: versionUnitId ? async (tx) => (await tx.getUnit(versionUnitId))?.version : null,
    mutate: async (tx) => {
    let destination = null;
    if (destinationDepartmentId) {
      destination = await tx.getUnit(destinationDepartmentId);
      if (!destination || destination.type !== 'department' || destination.archived === true) { const error = new Error('Invalid department'); error.code = 'invalid_input'; throw error; }
    }
    const users = await Promise.all(ids.map((id) => tx.getUser(id)));
    if (users.some((user) => !user || user.isActive !== true)) { const error = new Error('Invalid employee'); error.code = 'invalid_input'; throw error; }
    if (sourceDepartmentId && users.some((user) => (user.departmentUnitId || user.departmentId || null) !== sourceDepartmentId)) {
      const error = new Error('Employee is outside source department'); error.code = 'conflict'; throw error;
    }
    const departmentDeltas = new Map();
    for (let i = 0; i < ids.length; i += 1) {
      const previousDepartmentId = users[i].departmentUnitId || users[i].departmentId || null;
      if (previousDepartmentId !== destinationDepartmentId) {
        if (previousDepartmentId) departmentDeltas.set(previousDepartmentId, (departmentDeltas.get(previousDepartmentId) || 0) - 1);
        if (destinationDepartmentId) departmentDeltas.set(destinationDepartmentId, (departmentDeltas.get(destinationDepartmentId) || 0) + 1);
      }
      await tx.putUser(ids[i], { ...users[i], departmentId: destinationDepartmentId, departmentUnitId: destinationDepartmentId, directManagerId: directManagerUid, organizationUpdatedAt: now });
      if (typeof tx.putRouting === 'function') {
        await tx.putRouting(ids[i], {
          employeeUid: ids[i],
          managerUid: directManagerUid || null,
          departmentId: destinationDepartmentId || null,
          effectiveForFutureRequestsOnly: true,
          updatedAt: now,
        });
      }
    }
    let version = 1;
    const touchedDepartmentIds = new Set([...departmentDeltas.keys(), ...(destinationDepartmentId ? [destinationDepartmentId] : [])]);
    for (const departmentId of touchedDepartmentIds) {
      const unit = departmentId === destinationDepartmentId && destination
        ? destination
        : await tx.getUnit(departmentId);
      if (!unit || unit.type !== 'department') continue;
      const updatedVersion = Number(unit.version || 0) + 1;
      const updatedCount = Math.max(0, Number(unit.memberCount || 0) + Number(departmentDeltas.get(departmentId) || 0));
      await tx.putUnit(departmentId, { ...unit, memberCount: updatedCount, version: updatedVersion, updatedAt: now });
      if (departmentId === versionUnitId) version = updatedVersion;
    }
    return { resourceId: versionUnitId || 'unassigned', version, affectedEmployees: ids.length };
  } });
}

module.exports = { normalizeEmployeeIds, previewMembershipChange, applyMembershipChange };
