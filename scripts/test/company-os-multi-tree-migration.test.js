'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  DEFAULT_TREE_ID,
  buildMultiTreeMigrationPlan,
  buildOrganizationTreeBootstrapPlan,
} = require('../company-os/migrate-organization-trees');

test('default-tree migration is deterministic, additive, and idempotent', () => {
  const input = {
    units: [{ id: 'sales', type: 'sector' }, { id: 'inside-sales', type: 'department', parentId: 'sales' }],
    users: [{ id: 'u1', isActive: true, departmentUnitId: 'inside-sales', directManagerId: 'm1' }],
  };
  const first = buildMultiTreeMigrationPlan(input);
  const second = buildMultiTreeMigrationPlan(input);
  assert.equal(first.fingerprint, second.fingerprint);
  assert.equal(first.treeWrite.id, DEFAULT_TREE_ID);
  assert.equal(first.membershipWrites[0].value.isPrimary, true);
  assert.equal(first.rollback.destructiveWrites, 0);

  const converged = buildMultiTreeMigrationPlan({
    ...input,
    units: input.units.map((unit) => ({ ...unit, treeId: DEFAULT_TREE_ID })),
    existingTrees: [{ id: DEFAULT_TREE_ID }],
    existingMemberships: first.membershipWrites.map((write) => write.value),
    users: [{ ...input.users[0], primaryOrganizationMembershipId: first.membershipWrites[0].id }],
  });
  assert.deepEqual(converged.summary, { trees: 0, units: 0, memberships: 0, users: 0 });
});

test('legacy organization bootstrap is additive, deterministic, and never deletes legacy data', () => {
  const input = {
    divisions: [{ id: 'sales', name: 'المبيعات' }],
    departments: [{ id: 'inside', name: 'المبيعات الداخلية', divisionId: 'sales', managerUid: 'm1' }],
    users: [
      { id: 'm1', isActive: true },
      { id: 'u1', isActive: true, department: 'المبيعات الداخلية', directManagerId: 'm1' },
    ],
  };
  const first = buildOrganizationTreeBootstrapPlan(input);
  const second = buildOrganizationTreeBootstrapPlan(input);
  assert.equal(first.fingerprint, second.fingerprint);
  assert.equal(first.legacyUnitWrites.length, 2);
  assert.equal(first.membershipWrites.length, 1);
  assert.equal(first.membershipWrites[0].value.isPrimary, true);
  assert.equal(first.rollback.destructiveWrites, 0);
});

test('legacy bootstrap fills an existing active tree instead of creating a second empty tree', () => {
  const plan = buildOrganizationTreeBootstrapPlan({
    divisions: [{ id: 'sales', name: 'المبيعات' }],
    departments: [],
    users: [],
    existingTrees: [{ id: 'ZAWOLF', name: 'ZaWolf', status: 'active', isDefault: true }],
  });
  assert.equal(plan.treeWrite, null);
  assert.equal(plan.unitWrites[0].value.treeId, 'ZAWOLF');
});
