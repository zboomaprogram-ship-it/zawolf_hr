'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { identities } = require('./fixtures/company-os-fixtures');
const { authorizeCapability, roleScopes } = require('../company-os/authorization');

test('inactive employees always fail closed', () => {
  assert.equal(authorizeCapability({ actor: identities.inactive, capability: 'view_portal' }), false);
});

test('employee is self-scoped and cannot manage IT or Finance', () => {
  assert.equal(authorizeCapability({ actor: identities.employee, capability: 'view_portal' }), true);
  assert.equal(authorizeCapability({ actor: identities.employee, capability: 'manage_tickets' }), false);
  assert.equal(authorizeCapability({ actor: identities.employee, capability: 'view_employee', target: identities.outOfScope }), false);
});

test('operational roles receive only their server-derived capabilities', () => {
  assert.equal(authorizeCapability({ actor: identities.itSupport, capability: 'manage_tickets' }), true);
  assert.equal(authorizeCapability({ actor: identities.itSupport, capability: 'manage_access' }), false);
  assert.equal(authorizeCapability({ actor: identities.itManager, capability: 'manage_access' }), true);
  assert.equal(authorizeCapability({ actor: identities.finance, capability: 'review_finance' }), true);
  assert.equal(authorizeCapability({ actor: identities.manager, capability: 'view_employee', target: identities.employee }), true);
  assert.equal(authorizeCapability({ actor: identities.manager, capability: 'view_employee', target: identities.outOfScope }), false);
  assert.equal(authorizeCapability({ actor: identities.admin, capability: 'view_operations' }), true);
  assert.equal(authorizeCapability({ actor: identities.superAdmin, capability: 'manage_access' }), true);
  assert.deepEqual(roleScopes(identities.employee), ['self']);
});

