const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isHrOrAdmin,
  canManageDeveloperTools,
  isSelfOrAuthorizedTeamMember,
  auditActorContext,
} = require('../phase007-authorization');

test('only HR/admin roles pass the administrative authorization check', () => {
  assert.equal(isHrOrAdmin({ role: 'hr' }), true);
  assert.equal(isHrOrAdmin({ role: 'admin' }), true);
  assert.equal(isHrOrAdmin({ role: 'HR_ADMIN' }), true);
  assert.equal(isHrOrAdmin({ role: 'hr_admin' }), true);
  assert.equal(isHrOrAdmin({ role: 'manager' }), false);
});

test('team/self authorization does not turn arbitrary employees into reviewers', () => {
  assert.equal(isSelfOrAuthorizedTeamMember({ uid: 'a', role: 'employee' }, 'a'), true);
  assert.equal(isSelfOrAuthorizedTeamMember({ uid: 'a', role: 'employee' }, 'b'), false);
  assert.equal(isSelfOrAuthorizedTeamMember({ uid: 'm', role: 'manager', teamUserIds: ['b'] }, 'b'), true);
});

test('developer tools can only be managed by HR/admin roles', () => {
  assert.equal(canManageDeveloperTools({ role: 'hr_admin' }), true);
  assert.equal(canManageDeveloperTools({ role: 'manager' }), false);
  assert.equal(canManageDeveloperTools({ role: 'employee' }), false);
});

test('audit context only contains actor scope', () => {
  assert.deepEqual(auditActorContext({ uid: 'a', role: 'hr_admin' }), { actorId: 'a', actorRole: 'hr_admin' });
});
