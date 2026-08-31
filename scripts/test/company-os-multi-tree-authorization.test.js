'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  canManageOrganizationTree,
  requireOrganizationTreeManage,
} = require('../company-os/organization-authorization');

test('tree administrators are scoped to explicitly assigned trees', () => {
  const actor = {
    uid: 'tree-admin',
    active: true,
    role: 'employee',
    organizationTreeAdminIds: ['tree-a'],
  };
  assert.equal(canManageOrganizationTree(actor, 'tree-a'), true);
  assert.equal(canManageOrganizationTree(actor, 'tree-b'), false);
  assert.throws(() => requireOrganizationTreeManage(actor, 'tree-b'), (error) => error.code === 'access_denied');
});

test('global organization capability remains valid for every tree', () => {
  const actor = {
    uid: 'global-admin',
    active: true,
    role: 'employee',
    capabilities: ['organization_structure_manage'],
  };
  assert.equal(canManageOrganizationTree(actor, 'tree-a'), true);
  assert.equal(canManageOrganizationTree(actor, 'tree-b'), true);
});
