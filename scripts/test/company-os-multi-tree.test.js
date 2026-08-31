'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createTree,
  cloneTree,
  addTreeMemberships,
  setPrimaryTreeMembership,
  archiveTreeMembership,
  archiveTree,
  setTreeActive,
  setTreeLeadership,
} = require('../company-os/organization-trees');

function memoryStore() {
  const trees = new Map();
  const units = new Map();
  const memberships = new Map();
  const users = new Map();
  const receipts = new Map();
  const audits = new Map();
  let tail = Promise.resolve();
  const tx = {
    async getReceipt(id) { return receipts.get(id) || null; },
    async putReceipt(id, value) { receipts.set(id, value); },
    async putAudit(id, value) { audits.set(id, value); },
    async getTree(id) { return trees.get(id) || null; },
    async listTrees() { return [...trees.values()]; },
    async putTree(id, value) { trees.set(id, { ...value }); },
    async getUnit(id) { return units.get(id) || null; },
    async listUnitsForTree(treeId) {
      return [...units.values()].filter((item) => item.treeId === treeId);
    },
    async putUnit(id, value) { units.set(id, { ...value }); },
    async getMembership(id) { return memberships.get(id) || null; },
    async listMembershipsForEmployee(uid) {
      return [...memberships.values()].filter((item) => item.employeeUid === uid);
    },
    async listMembershipsForTree(treeId) {
      return [...memberships.values()].filter((item) => item.treeId === treeId);
    },
    async putMembership(id, value) { memberships.set(id, { ...value }); },
    async getUser(id) { return users.get(id) || null; },
    async putUser(id, value) { users.set(id, { ...value }); },
    async putRouting() {},
  };
  return {
    trees, units, memberships, users, receipts, audits,
    transact(work) {
      const result = tail.then(() => work(tx));
      tail = result.catch(() => {});
      return result;
    },
  };
}

const actor = {
  uid: 'admin-1',
  active: true,
  role: 'admin',
  capabilities: ['organization_structure_manage'],
};

test('creates independent trees with different root leaders idempotently', async () => {
  const store = memoryStore();
  store.users.set('ceo-a', { id: 'ceo-a', isActive: true });
  store.users.set('ceo-b', { id: 'ceo-b', isActive: true });

  const first = await createTree({
    store, actor, operationId: 'tree-create-0001',
    input: { id: 'tree-a', name: 'الشركة الأساسية', rootLeaderUid: 'ceo-a', isDefault: true },
  });
  const retry = await createTree({
    store, actor, operationId: 'tree-create-0001',
    input: { id: 'tree-a', name: 'الشركة الأساسية', rootLeaderUid: 'ceo-a', isDefault: true },
  });
  await createTree({
    store, actor, operationId: 'tree-create-0002',
    input: { id: 'tree-b', name: 'مشروع جديد', rootLeaderUid: 'ceo-b' },
  });

  assert.deepEqual(retry, first);
  assert.equal(store.trees.get('tree-a').rootLeaderUid, 'ceo-a');
  assert.equal(store.trees.get('tree-b').rootLeaderUid, 'ceo-b');
  assert.equal(store.audits.size, 2);
});

test('one employee can belong to multiple trees but has one primary projection', async () => {
  const store = memoryStore();
  store.trees.set('tree-a', { id: 'tree-a', name: 'A', status: 'active', version: 1 });
  store.trees.set('tree-b', { id: 'tree-b', name: 'B', status: 'active', version: 1 });
  store.units.set('dept-a', { id: 'dept-a', treeId: 'tree-a', type: 'department', archived: false });
  store.units.set('dept-b', { id: 'dept-b', treeId: 'tree-b', type: 'department', archived: false });
  store.users.set('employee-1', { id: 'employee-1', isActive: true });
  store.users.set('manager-a', { id: 'manager-a', isActive: true });
  store.users.set('manager-b', { id: 'manager-b', isActive: true });

  await addTreeMemberships({
    store, actor, operationId: 'membership-0001', treeId: 'tree-a',
    unitId: 'dept-a', employeeUids: ['employee-1'], directManagerUid: 'manager-a',
  });
  await addTreeMemberships({
    store, actor, operationId: 'membership-0002', treeId: 'tree-b',
    unitId: 'dept-b', employeeUids: ['employee-1'], directManagerUid: 'manager-b',
  });
  assert.equal(store.memberships.size, 2);
  assert.equal(store.users.get('employee-1').departmentUnitId, undefined);

  await setPrimaryTreeMembership({
    store, actor, operationId: 'membership-primary-0001',
    membershipId: 'tree-b_employee-1_dept-b', expectedVersion: 1,
  });
  const user = store.users.get('employee-1');
  assert.equal(user.primaryOrganizationTreeId, 'tree-b');
  assert.equal(user.departmentUnitId, 'dept-b');
  assert.equal(user.directManagerId, 'manager-b');
  assert.equal([...store.memberships.values()].filter((item) => item.isPrimary).length, 1);
});

test('cannot archive a tree with active memberships', async () => {
  const store = memoryStore();
  store.trees.set('tree-a', { id: 'tree-a', name: 'A', status: 'active', version: 1 });
  store.memberships.set('tree-a_employee-1_dept-a', {
    id: 'tree-a_employee-1_dept-a', treeId: 'tree-a', employeeUid: 'employee-1', status: 'active', version: 1,
  });
  await assert.rejects(
    archiveTree({ store, actor, operationId: 'tree-archive-0001', treeId: 'tree-a', expectedVersion: 1 }),
    (error) => error.code === 'conflict',
  );
});

test('archives a non-primary membership and refuses removing the primary membership', async () => {
  const store = memoryStore();
  store.memberships.set('secondary', {
    id: 'secondary', treeId: 'tree-a', employeeUid: 'employee-1',
    status: 'active', isPrimary: false, version: 2,
  });
  store.memberships.set('primary', {
    id: 'primary', treeId: 'tree-a', employeeUid: 'employee-1',
    status: 'active', isPrimary: true, version: 4,
  });
  const result = await archiveTreeMembership({
    store, actor, operationId: 'membership-archive-001',
    membershipId: 'secondary', expectedVersion: 2,
  });
  assert.equal(result.version, 3);
  assert.equal(store.memberships.get('secondary').status, 'archived');
  await assert.rejects(
    archiveTreeMembership({
      store, actor, operationId: 'membership-archive-002',
      membershipId: 'primary', expectedVersion: 4,
    }),
    (error) => error.code === 'conflict',
  );
});

test('clones hierarchy with secondary memberships while preserving original primary routing', async () => {
  const store = memoryStore();
  store.trees.set('source', { id: 'source', name: 'Source', status: 'active', version: 2 });
  store.units.set('sector-a', { id: 'sector-a', treeId: 'source', type: 'sector', parentId: null, managerUid: 'm1' });
  store.units.set('dept-a', { id: 'dept-a', treeId: 'source', type: 'department', parentId: 'sector-a', managerUid: 'm2' });
  store.memberships.set('old', {
    id: 'old', treeId: 'source', employeeUid: 'e1', unitId: 'dept-a',
    directManagerUid: 'm2', status: 'active', isPrimary: true, title: 'موظف', version: 3,
  });
  store.users.set('ceo-b', { id: 'ceo-b', isActive: true });
  store.users.set('m1', { id: 'm1', isActive: true });
  store.users.set('m2', { id: 'm2', isActive: true });
  store.users.set('e1', { id: 'e1', isActive: true, primaryOrganizationTreeId: 'source' });
  const result = await cloneTree({
    store, actor, operationId: 'tree-clone-001', sourceTreeId: 'source',
    input: { id: 'copy', name: 'نسخة تشغيلية', rootLeaderUid: 'ceo-b' },
  });
  assert.equal(result.clonedUnits, 2);
  assert.equal(result.clonedMemberships, 1);
  assert.equal(store.trees.get('copy').status, 'active');
  assert.equal(store.units.get('copy_dept-a').parentId, 'copy_sector-a');
  assert.equal(store.units.get('copy_dept-a').managerUid, 'm2');
  const copiedMembership = store.memberships.get('copy_e1_copy_dept-a');
  assert.equal(copiedMembership.isPrimary, false);
  assert.equal(copiedMembership.directManagerUid, 'm2');
  assert.equal(store.users.get('e1').primaryOrganizationTreeId, 'source');
});

test('can clone a hierarchy without staffing when explicitly requested', async () => {
  const store = memoryStore();
  store.trees.set('source', { id: 'source', name: 'Source', status: 'active', version: 1 });
  store.units.set('dept-a', { id: 'dept-a', treeId: 'source', type: 'department', parentId: null });
  store.memberships.set('old', { id: 'old', treeId: 'source', employeeUid: 'e1', unitId: 'dept-a', status: 'active' });
  const result = await cloneTree({
    store, actor, operationId: 'tree-clone-empty-001', sourceTreeId: 'source',
    input: { id: 'copy', name: 'نسخة بدون أعضاء', copyMemberships: false },
  });
  assert.equal(result.clonedMemberships, 0);
  assert.equal([...store.memberships.values()].filter((item) => item.treeId === 'copy').length, 0);
});

test('activates an archived or draft tree with optimistic versioning', async () => {
  const store = memoryStore();
  store.trees.set('tree-a', { id: 'tree-a', name: 'A', status: 'archived', version: 4 });
  const result = await setTreeActive({
    store, actor, operationId: 'tree-activate-001', treeId: 'tree-a', expectedVersion: 4,
  });
  assert.equal(result.version, 5);
  assert.equal(store.trees.get('tree-a').status, 'active');
});

test('updates root leader and scoped tree administrators without static roles', async () => {
  const store = memoryStore();
  store.trees.set('tree-a', {
    id: 'tree-a', name: 'A', status: 'active', version: 1, treeAdminUids: ['old-admin'],
  });
  store.users.set('leader', { id: 'leader', isActive: true });
  store.users.set('old-admin', { id: 'old-admin', isActive: true, organizationTreeAdminIds: ['tree-a'] });
  store.users.set('new-admin', { id: 'new-admin', isActive: true, organizationTreeAdminIds: ['other-tree'] });
  const result = await setTreeLeadership({
    store, actor, operationId: 'tree-leadership-001', treeId: 'tree-a',
    rootLeaderUid: 'leader', treeAdminUids: ['new-admin'], expectedVersion: 1,
  });
  assert.equal(result.version, 2);
  assert.deepEqual(store.trees.get('tree-a').treeAdminUids, ['new-admin']);
  assert.deepEqual(store.users.get('old-admin').organizationTreeAdminIds, []);
  assert.deepEqual(store.users.get('new-admin').organizationTreeAdminIds, ['other-tree', 'tree-a']);
});
