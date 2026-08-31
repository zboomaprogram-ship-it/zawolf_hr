'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  canReadOrganization,
  canManageOrganization,
} = require('../company-os/organization-authorization');

test('organization reads require active employment', () => {
  assert.equal(canReadOrganization({ uid: 'u1', active: true, role: 'employee' }), true);
  assert.equal(canReadOrganization({ uid: 'u1', active: false, role: 'super_admin' }), false);
});

test('managed capability controls writes without employee-code conditions', () => {
  assert.equal(canManageOrganization({ uid: 'hr1', active: true, capabilities: ['organization_structure_manage'] }), true);
  assert.equal(canManageOrganization({ uid: 'admin1', active: true, role: 'admin' }), true);
  assert.equal(canManageOrganization({ uid: 'root1', active: true, role: 'super_admin' }), true);
  assert.equal(canManageOrganization({ uid: 'manager1', active: true, role: 'manager' }), false);
  assert.equal(canManageOrganization({ uid: 'ceo-code-is-irrelevant', active: true, role: 'employee' }), false);
});
