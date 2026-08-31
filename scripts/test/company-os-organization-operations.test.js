'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createUnit,
  renameUnit,
  reorderUnits,
  moveDepartment,
  setUnitArchived,
} = require('../company-os/organization-structure');
const { assignPrimaryManager } = require('../company-os/organization-managers');
const { previewMembershipChange, applyMembershipChange } = require('../company-os/organization-membership');

function memoryStore() {
  const units = new Map(); const users = new Map(); const managers = new Map();
  const receipts = new Map(); const audits = new Map(); let tail = Promise.resolve();
  const tx = {
    receipts, audits,
    async getReceipt(id) { return receipts.get(id) || null; },
    async putReceipt(id, value) { receipts.set(id, value); },
    async putAudit(id, value) { audits.set(id, value); },
    async getUnit(id) { return units.get(id) || null; },
    async listUnits() { return [...units.values()]; },
    async putUnit(id, value) { units.set(id, { ...value }); },
    async getUser(id) { return users.get(id) || null; },
    async putUser(id, value) { users.set(id, { ...value }); },
    async putManager(id, value) { managers.set(id, { ...value }); },
    async currentManager(unitId) { return [...managers.values()].find((m) => m.unitId === unitId && !m.endedAt) || null; },
  };
  return {
    units, users, managers, receipts, audits, tx,
    transact(work) { const result = tail.then(() => work(tx)); tail = result.catch(() => {}); return result; },
  };
}

const actor = { uid: 'admin1', active: true, role: 'admin' };

test('unit mutations are idempotent, versioned, ordered, and conflict on payload reuse', async () => {
  const store = memoryStore();
  const sector = await createUnit({ store, actor, operationId: 'org-create-0001', input: { type: 'sector', name: 'العمليات' } });
  const retry = await createUnit({ store, actor, operationId: 'org-create-0001', input: { type: 'sector', name: 'العمليات' } });
  assert.deepEqual(retry, sector);
  assert.equal(store.units.size, 1);
  assert.equal(store.audits.size, 1);
  await assert.rejects(createUnit({ store, actor, operationId: 'org-create-0001', input: { type: 'sector', name: 'المبيعات' } }), (error) => error.code === 'conflict');

  const department = await createUnit({ store, actor, operationId: 'org-create-0002', input: { type: 'department', name: 'الدعم', parentId: sector.resourceId } });
  const destination = await createUnit({ store, actor, operationId: 'org-create-0003', input: { type: 'sector', name: 'التقنية' } });
  await renameUnit({ store, actor, operationId: 'org-rename-0001', unitId: department.resourceId, expectedVersion: 1, name: 'الدعم الفني' });
  await reorderUnits({ store, actor, operationId: 'org-order-0001', parentId: sector.resourceId, orderedIds: [department.resourceId] });
  await moveDepartment({ store, actor, operationId: 'org-move-0001', unitId: department.resourceId, destinationSectorId: destination.resourceId, expectedVersion: 3 });
  assert.equal(store.units.get(department.resourceId).name, 'الدعم الفني');
  assert.equal(store.units.get(department.resourceId).parentId, destination.resourceId);
});

test('archive constraints, active manager validation, preview and atomic bulk membership', async () => {
  const store = memoryStore();
  const sector = await createUnit({ store, actor, operationId: 'org-create-1001', input: { type: 'sector', name: 'الإدارة' } });
  const department = await createUnit({ store, actor, operationId: 'org-create-1002', input: { type: 'department', name: 'الموارد البشرية', parentId: sector.resourceId } });
  store.users.set('inactive-manager', { uid: 'inactive-manager', isActive: false });
  store.users.set('manager1', { uid: 'manager1', isActive: true });
  store.users.set('employee1', { uid: 'employee1', isActive: true, departmentId: null });
  await assert.rejects(
    assignPrimaryManager({ store, actor, operationId: 'org-manager-inactive-0001', unitId: department.resourceId, managerUid: 'inactive-manager', expectedVersion: 1 }),
    (error) => error.code === 'invalid_input',
  );
  await assignPrimaryManager({ store, actor, operationId: 'org-manager-0001', unitId: department.resourceId, managerUid: 'manager1', expectedVersion: 1 });
  const preview = await previewMembershipChange({ store, actor, employeeUids: ['employee1'], destinationDepartmentId: department.resourceId });
  assert.equal(preview.affectedEmployees, 1);
  await applyMembershipChange({ store, actor, operationId: 'org-members-0001', employeeUids: ['employee1'], destinationDepartmentId: department.resourceId, directManagerUid: 'manager1', expectedVersion: 2 });
  assert.equal(store.users.get('employee1').departmentId, department.resourceId);
  assert.equal(store.units.get(department.resourceId).version, 3);
  assert.equal(store.units.get(department.resourceId).memberCount, 1);
  await applyMembershipChange({ store, actor, operationId: 'org-members-remove-0001', employeeUids: ['employee1'], sourceDepartmentId: department.resourceId, destinationDepartmentId: null, expectedVersion: 3 });
  assert.equal(store.users.get('employee1').departmentId, null);
  assert.equal(store.units.get(department.resourceId).memberCount, 0);
  store.users.set('employee2', { uid: 'employee2', isActive: true, departmentId: null });
  await assert.rejects(
    applyMembershipChange({ store, actor, operationId: 'org-members-0002', employeeUids: ['employee2'], destinationDepartmentId: department.resourceId, directManagerUid: 'manager1', expectedVersion: 3 }),
    (error) => error.code === 'conflict',
  );
  assert.equal(store.users.get('employee2').departmentId, null);
  await assert.rejects(setUnitArchived({ store, actor, operationId: 'org-archive-0001', unitId: department.resourceId, archived: true, expectedVersion: 4 }), (error) => error.code === 'conflict');

  const emptyDepartment = await createUnit({ store, actor, operationId: 'org-create-1003', input: { type: 'department', name: 'الشؤون القانونية', parentId: sector.resourceId } });
  const archived = await setUnitArchived({ store, actor, operationId: 'org-archive-0002', unitId: emptyDepartment.resourceId, archived: true, expectedVersion: 1 });
  assert.equal(archived.unit.archived, true);
  const restored = await setUnitArchived({ store, actor, operationId: 'org-restore-0001', unitId: emptyDepartment.resourceId, archived: false, expectedVersion: 2 });
  assert.equal(restored.unit.archived, false);
  await assert.rejects(
    setUnitArchived({ store, actor, operationId: 'org-archive-0003', unitId: emptyDepartment.resourceId, archived: true, expectedVersion: 1 }),
    (error) => error.code === 'conflict',
  );
});
