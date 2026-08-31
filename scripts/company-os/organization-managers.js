'use strict';

const crypto = require('node:crypto');
const { executeOperation } = require('./operation-gateway');
const { requireOrganizationManage } = require('./organization-authorization');

async function assignPrimaryManager({ store, actor, operationId, unitId, managerUid = null, expectedVersion = null, now = new Date() }) {
  requireOrganizationManage(actor);
  return executeOperation({ store, operationId, actor, operationType: 'organization_manager_assign', targetId: unitId,
    payload: { unitId, managerUid }, expectedVersion, currentVersion: async (tx) => (await tx.getUnit(unitId))?.version,
    mutate: async (tx) => {
      const unit = await tx.getUnit(unitId);
      if (!unit || unit.type !== 'department' || unit.archived === true) { const error = new Error('Invalid department'); error.code = 'invalid_input'; throw error; }
      if (managerUid) {
        const manager = await tx.getUser(managerUid);
        if (!manager || manager.isActive !== true) { const error = new Error('Inactive manager'); error.code = 'invalid_input'; throw error; }
      }
      const current = await tx.currentManager(unitId);
      if (current && typeof tx.putManager === 'function') await tx.putManager(current.id, { ...current, endedAt: now, endedBy: actor.uid });
      if (managerUid) {
        const assignment = { id: `manager_${crypto.randomUUID()}`, unitId, managerUid, startedAt: now, endedAt: null, assignedBy: actor.uid };
        await tx.putManager(assignment.id, assignment);
      }
      const updated = { ...unit, managerUid: managerUid || null, managerVacant: !managerUid, version: Number(unit.version || 0) + 1, updatedAt: now };
      await tx.putUnit(unitId, updated);
      const members = typeof tx.listDepartmentMembers === 'function'
        ? await tx.listDepartmentMembers(unitId)
        : [];
      for (const member of members) {
        await tx.putUser(member.id, { directManagerId: managerUid || null, organizationUpdatedAt: now });
        if (typeof tx.putRouting === 'function') {
          await tx.putRouting(member.id, {
            employeeUid: member.id,
            managerUid: managerUid || null,
            departmentId: unitId,
            effectiveForFutureRequestsOnly: true,
            updatedAt: now,
          });
        }
      }
      return { resourceId: unitId, version: updated.version, managerUid: managerUid || null, managerVacant: !managerUid, affectedEmployees: members.length };
    } });
}

module.exports = { assignPrimaryManager };
