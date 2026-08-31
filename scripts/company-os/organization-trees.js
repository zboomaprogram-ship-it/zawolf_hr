'use strict';

const { executeOperation } = require('./operation-gateway');
const { requireOrganizationManage, requireOrganizationRead, requireOrganizationTreeManage } = require('./organization-authorization');

function fail(code, message) {
  const error = new Error(message);
  error.code = code;
  throw error;
}

function cleanId(value, label) {
  const result = String(value || '').trim();
  if (!result || result.length > 128) fail('invalid_input', `Invalid ${label}`);
  return result;
}

function cleanName(value) {
  const result = String(value || '').trim();
  if (result.length < 2 || result.length > 120) fail('invalid_input', 'Invalid tree name');
  return result;
}

function normalizeEmployeeIds(values) {
  const ids = [...new Set((values || []).map((value) => String(value || '').trim()).filter(Boolean))];
  if (!ids.length || ids.length > 100) fail('invalid_input', 'Invalid employees');
  return ids;
}

function normalizeOptionalEmployeeIds(values) {
  const ids = [...new Set((values || []).map((value) => String(value || '').trim()).filter(Boolean))];
  if (ids.length > 50) fail('invalid_input', 'Invalid tree administrators');
  return ids;
}

async function createTree({ store, actor, operationId, input, now = new Date() }) {
  requireOrganizationManage(actor);
  const id = cleanId(input?.id, 'tree id');
  const name = cleanName(input?.name);
  const rootLeaderUid = input?.rootLeaderUid ? cleanId(input.rootLeaderUid, 'root leader') : null;
  const isDefault = input?.isDefault === true;
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_create',
    targetId: id,
    payload: { id, name, purpose: input?.purpose || null, rootLeaderUid, isDefault },
    mutate: async (tx) => {
      if (await tx.getTree(id)) fail('conflict', 'Tree already exists');
      if (rootLeaderUid) {
        const leader = await tx.getUser(rootLeaderUid);
        if (!leader || leader.isActive !== true) fail('invalid_input', 'Invalid root leader');
      }
      const trees = await tx.listTrees();
      if (isDefault && trees.some((tree) => tree.status === 'active' && tree.isDefault === true)) {
        fail('conflict', 'An active default tree already exists');
      }
      const tree = {
        id,
        name,
        purpose: String(input?.purpose || '').trim() || null,
        rootLeaderUid,
        isDefault,
        status: 'active',
        order: Number.isFinite(Number(input?.order)) ? Number(input.order) : trees.length,
        version: 1,
        createdAt: now,
        updatedAt: now,
      };
      await tx.putTree(id, tree);
      return { resourceId: id, version: 1, tree };
    },
  });
}

async function addTreeMemberships({
  store,
  actor,
  operationId,
  treeId,
  unitId,
  employeeUids,
  directManagerUid = null,
  title = null,
  now = new Date(),
}) {
  requireOrganizationRead(actor);
  const cleanTreeId = cleanId(treeId, 'tree id');
  requireOrganizationTreeManage(actor, cleanTreeId);
  const cleanUnitId = cleanId(unitId, 'unit id');
  const ids = normalizeEmployeeIds(employeeUids);
  const managerUid = directManagerUid ? cleanId(directManagerUid, 'manager') : null;
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_membership_add',
    targetId: cleanTreeId,
    payload: { treeId: cleanTreeId, unitId: cleanUnitId, employeeUids: ids, directManagerUid: managerUid, title },
    mutate: async (tx) => {
      const tree = await tx.getTree(cleanTreeId);
      if (!tree || tree.status !== 'active') fail('invalid_input', 'Invalid tree');
      const unit = await tx.getUnit(cleanUnitId);
      if (!unit || unit.archived === true || unit.treeId !== cleanTreeId) fail('invalid_input', 'Invalid tree unit');
      if (managerUid) {
        const manager = await tx.getUser(managerUid);
        if (!manager || manager.isActive !== true) fail('invalid_input', 'Invalid manager');
      }
      const users = await Promise.all(ids.map((id) => tx.getUser(id)));
      if (users.some((user) => !user || user.isActive !== true)) fail('invalid_input', 'Invalid employee');
      const membershipIds = [];
      for (const employeeUid of ids) {
        const membershipId = `${cleanTreeId}_${employeeUid}_${cleanUnitId}`;
        const existing = await tx.getMembership(membershipId);
        if (existing?.status === 'active') fail('conflict', 'Membership already exists');
        await tx.putMembership(membershipId, {
          id: membershipId,
          treeId: cleanTreeId,
          employeeUid,
          unitId: cleanUnitId,
          directManagerUid: managerUid,
          title: String(title || '').trim() || null,
          isPrimary: false,
          status: 'active',
          version: Number(existing?.version || 0) + 1,
          createdAt: existing?.createdAt || now,
          updatedAt: now,
        });
        membershipIds.push(membershipId);
      }
      return { resourceId: cleanTreeId, version: Number(tree.version || 1), membershipIds, affectedEmployees: ids.length };
    },
  });
}

async function setPrimaryTreeMembership({ store, actor, operationId, membershipId, expectedVersion, now = new Date() }) {
  requireOrganizationRead(actor);
  const cleanMembershipId = cleanId(membershipId, 'membership id');
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_membership_primary',
    targetId: cleanMembershipId,
    payload: { membershipId: cleanMembershipId },
    expectedVersion,
    currentVersion: async (tx) => (await tx.getMembership(cleanMembershipId))?.version,
    mutate: async (tx) => {
      const selected = await tx.getMembership(cleanMembershipId);
      if (!selected || selected.status !== 'active') fail('invalid_input', 'Invalid membership');
      requireOrganizationTreeManage(actor, selected.treeId);
      const user = await tx.getUser(selected.employeeUid);
      if (!user || user.isActive !== true) fail('invalid_input', 'Invalid employee');
      const memberships = await tx.listMembershipsForEmployee(selected.employeeUid);
      for (const membership of memberships) {
        const shouldBePrimary = membership.id === cleanMembershipId;
        if (membership.isPrimary === shouldBePrimary) continue;
        await tx.putMembership(membership.id, {
          ...membership,
          isPrimary: shouldBePrimary,
          version: Number(membership.version || 0) + 1,
          updatedAt: now,
        });
      }
      const projected = {
        ...user,
        primaryOrganizationTreeId: selected.treeId,
        primaryOrganizationMembershipId: selected.id,
        departmentId: selected.unitId,
        departmentUnitId: selected.unitId,
        directManagerId: selected.directManagerUid || null,
        managerId: selected.directManagerUid || null,
        managerIds: selected.directManagerUid ? [selected.directManagerUid] : [],
        organizationUpdatedAt: now,
      };
      await tx.putUser(selected.employeeUid, projected);
      if (typeof tx.putRouting === 'function') {
        await tx.putRouting(selected.employeeUid, {
          employeeUid: selected.employeeUid,
          organizationTreeId: selected.treeId,
          organizationMembershipId: selected.id,
          departmentId: selected.unitId,
          managerUid: selected.directManagerUid || null,
          effectiveForFutureRequestsOnly: true,
          updatedAt: now,
        });
      }
      const version = Number(selected.version || 0) + (selected.isPrimary ? 0 : 1);
      return { resourceId: cleanMembershipId, version, employeeUid: selected.employeeUid };
    },
  });
}

async function archiveTreeMembership({ store, actor, operationId, membershipId, expectedVersion, now = new Date() }) {
  requireOrganizationRead(actor);
  const cleanMembershipId = cleanId(membershipId, 'membership id');
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_membership_archive',
    targetId: cleanMembershipId,
    payload: { membershipId: cleanMembershipId },
    expectedVersion,
    currentVersion: async (tx) => (await tx.getMembership(cleanMembershipId))?.version,
    mutate: async (tx) => {
      const membership = await tx.getMembership(cleanMembershipId);
      if (!membership || membership.status !== 'active') fail('invalid_input', 'Invalid membership');
      requireOrganizationTreeManage(actor, membership.treeId);
      if (membership.isPrimary === true) {
        fail('conflict', 'Primary membership must be changed before removal');
      }
      const version = Number(membership.version || 0) + 1;
      await tx.putMembership(cleanMembershipId, {
        ...membership,
        status: 'archived',
        version,
        updatedAt: now,
      });
      return { resourceId: cleanMembershipId, version, employeeUid: membership.employeeUid };
    },
  });
}

async function archiveTree({ store, actor, operationId, treeId, expectedVersion, now = new Date() }) {
  requireOrganizationRead(actor);
  const cleanTreeId = cleanId(treeId, 'tree id');
  requireOrganizationTreeManage(actor, cleanTreeId);
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_archive',
    targetId: cleanTreeId,
    payload: { treeId: cleanTreeId },
    expectedVersion,
    currentVersion: async (tx) => (await tx.getTree(cleanTreeId))?.version,
    mutate: async (tx) => {
      const tree = await tx.getTree(cleanTreeId);
      if (!tree) return { resourceId: cleanTreeId, version: 1 };
      if (tree.isDefault === true) fail('conflict', 'Default tree cannot be deleted');
      const memberships = await tx.listMembershipsForTree(cleanTreeId);
      const activeMemberships = memberships.filter((m) => m.status === 'active');
      if (activeMemberships.length > 0) {
        fail('conflict', 'Cannot archive a tree with active memberships');
      }
      for (const m of memberships) {
        if (typeof tx.deleteMembership === 'function') {
          await tx.deleteMembership(m.id);
        } else {
          await tx.putMembership(m.id, { ...m, status: 'archived', updatedAt: now });
        }
      }
      const units = await tx.listUnitsForTree(cleanTreeId);
      for (const u of units) {
        if (typeof tx.deleteUnit === 'function') {
          await tx.deleteUnit(u.id);
        } else {
          await tx.putUnit(u.id, { ...u, archived: true, updatedAt: now });
        }
      }
      if (typeof tx.deleteTree === 'function') {
        await tx.deleteTree(cleanTreeId);
      } else {
        await tx.putTree(cleanTreeId, { ...tree, status: 'archived', updatedAt: now });
      }
      return { resourceId: cleanTreeId, version: Number(tree.version || 0) + 1, deleted: true };
    },
  });
}

async function setTreeActive({ store, actor, operationId, treeId, expectedVersion, now = new Date() }) {
  requireOrganizationRead(actor);
  const cleanTreeId = cleanId(treeId, 'tree id');
  requireOrganizationTreeManage(actor, cleanTreeId);
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_activate',
    targetId: cleanTreeId,
    payload: { treeId: cleanTreeId },
    expectedVersion,
    currentVersion: async (tx) => (await tx.getTree(cleanTreeId))?.version,
    mutate: async (tx) => {
      const tree = await tx.getTree(cleanTreeId);
      if (!tree) fail('invalid_input', 'Invalid tree');
      if (tree.status === 'active') return {
        resourceId: cleanTreeId,
        version: Number(tree.version || 1),
      };
      const version = Number(tree.version || 0) + 1;
      await tx.putTree(cleanTreeId, { ...tree, status: 'active', version, updatedAt: now });
      return { resourceId: cleanTreeId, version };
    },
  });
}

async function cloneTree({ store, actor, operationId, sourceTreeId, input, now = new Date() }) {
  requireOrganizationManage(actor);
  const cleanSourceTreeId = cleanId(sourceTreeId, 'source tree id');
  const id = cleanId(input?.id, 'tree id');
  const name = cleanName(input?.name);
  const rootLeaderUid = input?.rootLeaderUid ? cleanId(input.rootLeaderUid, 'root leader') : null;
  // A copied tree is intended to be immediately useful.  Employees remain in
  // their original tree (and keep its primary routing), but are also copied as
  // secondary memberships into the new draft.  Callers can opt out for an
  // intentionally empty staffing model.
  const copyMemberships = input?.copyMemberships !== false;
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_clone',
    targetId: id,
    payload: { sourceTreeId: cleanSourceTreeId, id, name, rootLeaderUid, copyMemberships },
    mutate: async (tx) => {
      const [source, existing, trees, units, memberships, leader] = await Promise.all([
        tx.getTree(cleanSourceTreeId),
        tx.getTree(id),
        tx.listTrees(),
        tx.listUnitsForTree(cleanSourceTreeId),
        copyMemberships ? tx.listMembershipsForTree(cleanSourceTreeId) : Promise.resolve([]),
        rootLeaderUid ? tx.getUser(rootLeaderUid) : Promise.resolve(null),
      ]);
      const effectiveSource = source || trees.find((t) => t.isDefault) || trees[0] || { id: cleanSourceTreeId, purpose: null, treeAdminUids: [] };
      if (existing) fail('conflict', 'Tree already exists');
      if (rootLeaderUid && (!leader || leader.isActive !== true)) fail('invalid_input', 'Invalid root leader');
      const sourceAdmins = normalizeOptionalEmployeeIds(effectiveSource.treeAdminUids || []);
      const adminUsers = await Promise.all(sourceAdmins.map((uid) => tx.getUser(uid)));
      if (adminUsers.some((user) => !user || user.isActive !== true)) {
        fail('invalid_input', 'Invalid source tree administrator');
      }
      let sourceUnits = units;
      let sourceMemberships = memberships;
      if (sourceUnits.length === 0) {
        for (const t of trees) {
          const tUnits = await tx.listUnitsForTree(t.id);
          if (tUnits.length > 0) {
            sourceUnits = tUnits;
            if (copyMemberships) {
              sourceMemberships = await tx.listMembershipsForTree(t.id);
            }
            break;
          }
        }
        if (sourceUnits.length === 0 && typeof tx.listUnits === 'function') {
          sourceUnits = await tx.listUnits();
        }
      }
      const tree = {
        id,
        name,
        purpose: String(input?.purpose || effectiveSource.purpose || '').trim() || null,
        rootLeaderUid: rootLeaderUid || effectiveSource.rootLeaderUid || null,
        treeAdminUids: sourceAdmins,
        sourceTreeId: cleanSourceTreeId,
        isDefault: false,
        status: String(input?.status || 'active').trim(),
        order: trees.length,
        version: 1,
        createdAt: now,
        updatedAt: now,
      };
      await tx.putTree(id, tree);
      for (let index = 0; index < sourceAdmins.length; index += 1) {
        const uid = sourceAdmins[index];
        const user = adminUsers[index];
        const scoped = new Set((user.organizationTreeAdminIds || []).map(String));
        scoped.add(id);
        await tx.putUser(uid, { ...user, organizationTreeAdminIds: [...scoped].sort(), updatedAt: now });
      }
      const unitIdMap = new Map(sourceUnits.map((unit) => [unit.id, `${id}_${unit.id}`]));
      for (const unit of sourceUnits) {
        const clonedId = unitIdMap.get(unit.id);
        await tx.putUnit(clonedId, {
          ...unit,
          id: clonedId,
          treeId: id,
          parentId: unit.parentId ? unitIdMap.get(unit.parentId) || null : null,
          // Managers are employee references, so they remain valid across
          // trees.  This does not alter anybody's primary organization route.
          managerUid: unit.managerUid || null,
          version: 1,
          archived: false,
          sourceUnitId: unit.id,
          createdAt: now,
          updatedAt: now,
        });
      }
      let clonedMemberships = 0;
      let skippedMemberships = 0;
      for (const membership of sourceMemberships) {
        if (membership.status !== 'active') continue;
        const unitId = unitIdMap.get(membership.unitId);
        if (!unitId) {
          skippedMemberships += 1;
          continue;
        }
        const employee = await tx.getUser(membership.employeeUid);
        const manager = membership.directManagerUid
          ? await tx.getUser(membership.directManagerUid)
          : null;
        if (!employee || employee.isActive !== true || (membership.directManagerUid && (!manager || manager.isActive !== true))) {
          skippedMemberships += 1;
          continue;
        }
        const membershipId = `${id}_${membership.employeeUid}_${unitId}`;
        await tx.putMembership(membershipId, {
          ...membership,
          id: membershipId,
          treeId: id,
          unitId,
          // Never take over the original tree's routing during a clone.
          isPrimary: false,
          status: 'active',
          version: 1,
          sourceMembershipId: membership.id,
          createdAt: now,
          updatedAt: now,
        });
        clonedMemberships += 1;
      }
      return {
        resourceId: id,
        version: 1,
        tree,
        clonedUnits: units.length,
        clonedMemberships,
        skippedMemberships,
      };
    },
  });
}

async function setTreeLeadership({
  store, actor, operationId, treeId, rootLeaderUid, treeAdminUids, expectedVersion, now = new Date(),
}) {
  requireOrganizationManage(actor);
  const cleanTreeId = cleanId(treeId, 'tree id');
  const leaderUid = rootLeaderUid ? cleanId(rootLeaderUid, 'root leader') : null;
  const adminUids = normalizeOptionalEmployeeIds(treeAdminUids);
  return executeOperation({
    store,
    operationId,
    actor,
    operationType: 'organization_tree_leadership_update',
    targetId: cleanTreeId,
    payload: { treeId: cleanTreeId, rootLeaderUid: leaderUid, treeAdminUids: adminUids },
    expectedVersion,
    currentVersion: async (tx) => (await tx.getTree(cleanTreeId))?.version,
    mutate: async (tx) => {
      const tree = await tx.getTree(cleanTreeId);
      if (!tree) fail('invalid_input', 'Invalid tree');
      const previousAdmins = normalizeOptionalEmployeeIds(tree.treeAdminUids || []);
      const involved = [...new Set([...previousAdmins, ...adminUids, ...(leaderUid ? [leaderUid] : [])])];
      const users = await Promise.all(involved.map((uid) => tx.getUser(uid)));
      if (users.some((user) => !user || user.isActive !== true)) fail('invalid_input', 'Invalid tree leader or administrator');
      const byUid = new Map(involved.map((uid, index) => [uid, users[index]]));
      const version = Number(tree.version || 0) + 1;
      await tx.putTree(cleanTreeId, {
        ...tree, rootLeaderUid: leaderUid, treeAdminUids: adminUids, version, updatedAt: now,
      });
      for (const uid of involved) {
        const user = byUid.get(uid);
        const scoped = new Set((user.organizationTreeAdminIds || []).map(String));
        if (adminUids.includes(uid)) scoped.add(cleanTreeId); else scoped.delete(cleanTreeId);
        await tx.putUser(uid, { ...user, organizationTreeAdminIds: [...scoped].sort(), updatedAt: now });
      }
      return { resourceId: cleanTreeId, version, rootLeaderUid: leaderUid, treeAdminUids: adminUids };
    },
  });
}

module.exports = {
  createTree,
  cloneTree,
  addTreeMemberships,
  setPrimaryTreeMembership,
  archiveTreeMembership,
  archiveTree,
  setTreeActive,
  setTreeLeadership,
};
