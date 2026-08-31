'use strict';

const crypto = require('node:crypto');
const { executeOperation } = require('./operation-gateway');
const { requireOrganizationManage } = require('./organization-authorization');

function normalizedName(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').toLocaleLowerCase('ar');
}

function validateName(value) {
  const name = String(value || '').trim().replace(/\s+/g, ' ');
  if (name.length < 2 || name.length > 100) {
    const error = new Error('Invalid unit name'); error.code = 'invalid_input'; throw error;
  }
  return name;
}

function makeUnitId(type) { return `${type}_${crypto.randomUUID()}`; }

function treeOf(unit) { return String(unit?.treeId || 'default'); }

async function ensureUniqueName(tx, { name, type, parentId = null, treeId = 'default', exceptId = null }) {
  const collision = (await tx.listUnits()).find((unit) => unit.id !== exceptId
    && treeOf(unit) === treeId
    && unit.type === type && (unit.parentId || null) === parentId
    && unit.archived !== true && normalizedName(unit.name) === normalizedName(name));
  if (collision) { const error = new Error('Duplicate unit name'); error.code = 'conflict'; throw error; }
}

async function createUnit({ store, actor, operationId, input, now = new Date() }) {
  requireOrganizationManage(actor);
  const type = String(input?.type || '');
  if (!['sector', 'department'].includes(type)) { const error = new Error('Invalid unit type'); error.code = 'invalid_input'; throw error; }
  const name = validateName(input?.name);
  const parentId = type === 'department' ? String(input?.parentId || '') : null;
  const treeId = String(input?.treeId || 'default').trim();
  if (!treeId) { const error = new Error('Invalid tree'); error.code = 'invalid_input'; throw error; }
  if (type === 'department' && !parentId) { const error = new Error('Department requires sector'); error.code = 'invalid_input'; throw error; }
  const unitId = String(input?.id || makeUnitId(type));
  return executeOperation({
    store, operationId, actor, operationType: 'organization_unit_create', targetId: unitId,
    payload: { type, name, parentId, treeId }, now,
    mutate: async (tx) => {
      if (await tx.getUnit(unitId)) { const error = new Error('Existing unit'); error.code = 'conflict'; throw error; }
      if (parentId) {
        const parent = await tx.getUnit(parentId);
        if (!parent || parent.type !== 'sector' || parent.archived === true || treeOf(parent) !== treeId) { const error = new Error('Invalid sector'); error.code = 'invalid_input'; throw error; }
      }
      await ensureUniqueName(tx, { name, type, parentId, treeId });
      const siblings = (await tx.listUnits()).filter((unit) => treeOf(unit) === treeId && (unit.parentId || null) === parentId && unit.archived !== true);
      const unit = { id: unitId, treeId, type, parentId, name, normalizedName: normalizedName(name), order: siblings.length, archived: false, version: 1, createdAt: now, updatedAt: now };
      await tx.putUnit(unitId, unit);
      return { resourceId: unitId, version: 1, unit };
    },
  });
}

async function renameUnit({ store, actor, operationId, unitId, expectedVersion, name, now = new Date() }) {
  requireOrganizationManage(actor); const cleanName = validateName(name);
  return executeOperation({ store, operationId, actor, operationType: 'organization_unit_rename', targetId: unitId,
    payload: { unitId, name: cleanName }, expectedVersion,
    currentVersion: async (tx) => (await tx.getUnit(unitId))?.version,
    mutate: async (tx) => {
      const unit = await tx.getUnit(unitId); if (!unit) { const error = new Error('Missing unit'); error.code = 'invalid_input'; throw error; }
      await ensureUniqueName(tx, { name: cleanName, type: unit.type, parentId: unit.parentId || null, treeId: treeOf(unit), exceptId: unitId });
      const updated = { ...unit, name: cleanName, normalizedName: normalizedName(cleanName), version: Number(unit.version || 0) + 1, updatedAt: now };
      await tx.putUnit(unitId, updated); return { resourceId: unitId, version: updated.version, unit: updated };
    } });
}

async function reorderUnits({ store, actor, operationId, parentId = null, orderedIds, now = new Date() }) {
  requireOrganizationManage(actor); const ids = [...new Set((orderedIds || []).map(String))];
  if (!ids.length) { const error = new Error('Empty order'); error.code = 'invalid_input'; throw error; }
  return executeOperation({ store, operationId, actor, operationType: 'organization_units_reorder', targetId: parentId || 'root', payload: { parentId, orderedIds: ids }, mutate: async (tx) => {
    const units = await Promise.all(ids.map((id) => tx.getUnit(id)));
    if (units.some((unit) => !unit || (unit.parentId || null) !== (parentId || null) || treeOf(unit) !== treeOf(units[0]))) { const error = new Error('Invalid order'); error.code = 'conflict'; throw error; }
    for (let i = 0; i < units.length; i += 1) await tx.putUnit(ids[i], { ...units[i], order: i, version: Number(units[i].version || 0) + 1, updatedAt: now });
    return { resourceId: parentId || 'root', version: Math.max(...units.map((u) => Number(u.version || 0))) + 1, orderedIds: ids };
  } });
}

async function moveDepartment({ store, actor, operationId, unitId, destinationSectorId, expectedVersion, now = new Date() }) {
  requireOrganizationManage(actor);
  const destinationId = String(destinationSectorId || '').trim();
  if (!destinationId) { const error = new Error('Missing destination'); error.code = 'invalid_input'; throw error; }
  return executeOperation({ store, operationId, actor, operationType: 'organization_department_move', targetId: unitId,
    payload: { unitId, destinationSectorId: destinationId }, expectedVersion,
    currentVersion: async (tx) => (await tx.getUnit(unitId))?.version,
    mutate: async (tx) => {
      const unit = await tx.getUnit(unitId);
      const destination = await tx.getUnit(destinationId);
      if (!unit || unit.type !== 'department' || unit.archived === true
        || !destination || destination.type !== 'sector' || destination.archived === true
        || treeOf(unit) !== treeOf(destination)
        || unit.id === destination.id) {
        const error = new Error('Invalid move'); error.code = 'invalid_input'; throw error;
      }
      await ensureUniqueName(tx, { name: unit.name, type: unit.type, parentId: destinationId, treeId: treeOf(unit), exceptId: unitId });
      const siblings = (await tx.listUnits()).filter((candidate) => treeOf(candidate) === treeOf(unit) && candidate.parentId === destinationId && candidate.archived !== true && candidate.id !== unitId);
      const updated = { ...unit, parentId: destinationId, order: siblings.length, version: Number(unit.version || 0) + 1, updatedAt: now };
      await tx.putUnit(unitId, updated);
      return { resourceId: unitId, version: updated.version, unit: updated };
    } });
}

async function setUnitArchived({ store, actor, operationId, unitId, archived, expectedVersion, now = new Date() }) {
  requireOrganizationManage(actor);
  return executeOperation({ store, operationId, actor, operationType: archived ? 'organization_unit_archive' : 'organization_unit_restore', targetId: unitId, payload: { unitId, archived: archived === true }, expectedVersion,
    currentVersion: async (tx) => (await tx.getUnit(unitId))?.version,
    mutate: async (tx) => {
    const unit = await tx.getUnit(unitId); if (!unit) { const error = new Error('Missing'); error.code = 'invalid_input'; throw error; }
    if (archived) {
      const children = (await tx.listUnits()).filter((candidate) => candidate.parentId === unitId && candidate.archived !== true);
      const members = typeof tx.listUsersByDepartment === 'function' ? await tx.listUsersByDepartment(unitId) : [];
      const manager = typeof tx.currentManager === 'function' ? await tx.currentManager(unitId) : null;
      if (children.length || members.length || manager) { const error = new Error('Unit has dependencies'); error.code = 'conflict'; throw error; }
    }
    const updated = { ...unit, archived: archived === true, version: Number(unit.version || 0) + 1, updatedAt: now };
    await tx.putUnit(unitId, updated); return { resourceId: unitId, version: updated.version, unit: updated };
    } });
}

function canonicalHierarchy(units) {
  return [...units].sort((a, b) => Number(a.order || 0) - Number(b.order || 0) || String(a.id).localeCompare(String(b.id)));
}

module.exports = { normalizedName, canonicalHierarchy, createUnit, renameUnit, reorderUnits, moveDepartment, setUnitArchived, treeOf };
