const test = require('node:test');
const assert = require('node:assert/strict');
const {
  canAccessWorkspaceResource,
  isWorkspaceController,
} = require('../workspace/authorization');
const { validatePageSize, validateParentResourceId } = require('../workspace/resource-navigation');
const fs = require('node:fs');
const path = require('node:path');

const employee = { uid: 'employee-1', role: 'employee', department: 'Sales', teamIds: ['team-a'] };

test('authorization accepts inherited grants and explicit denial wins', () => {
  const allowed = [{ isActive: true, scope: 'department', subjectId: 'Sales', capability: 'edit' }];
  assert.equal(canAccessWorkspaceResource({ actor: employee, grants: allowed, capability: 'edit' }), true);
  const denied = [...allowed, {
    isActive: true, scope: 'employee', subjectId: 'employee-1', capability: 'view', effect: 'deny',
  }];
  assert.equal(canAccessWorkspaceResource({ actor: employee, grants: denied, capability: 'view' }), false);
});

test('controller status is dynamic and has no employee code condition', () => {
  assert.equal(isWorkspaceController({ role: 'manager', department: 'Information Technology' }), true);
  assert.equal(isWorkspaceController({ role: 'manager', position: 'IT Manager' }), true);
  assert.equal(isWorkspaceController({ role: 'manager', department: 'Sales' }), false);
});

test('a direct link without a grant is denied', () => {
  assert.equal(canAccessWorkspaceResource({ actor: employee, grants: [], capability: 'view' }), false);
});

test('V2 resource route uses bounded actor-scoped grant queries', () => {
  const server = fs.readFileSync(path.join(__dirname, '..', 'notification-web.js'), 'utf8');
  assert.match(server, /\/company-workspace\/v2\/resources/);
  assert.match(server, /where\('userId', '==', actor\.uid\)\.limit\(pageSize\)\.get\(\)/);
  assert.match(server, /where\('subjectId', '==', subjectId\)\.limit\(pageSize\)\.get\(\)/);
  assert.doesNotMatch(server, /workspaceAccessGrants'\)\.get\(\)/);
});

test('resource navigation rejects unbounded page sizes and malformed parent IDs', () => {
  assert.equal(validatePageSize('100'), 100);
  assert.throws(() => validatePageSize('101'), /حجم الصفحة/);
  assert.equal(validateParentResourceId(null), null);
  assert.throws(() => validateParentResourceId('../sensitive'), /المجلد/);
});
