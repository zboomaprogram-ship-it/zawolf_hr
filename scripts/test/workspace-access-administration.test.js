const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeWorkspaceGrant,
  grantDocumentId,
} = require('../workspace/access-administration');
const { planWorkspaceSourceImport } = require('../workspace/source-import');
const { canAccessWorkspaceResource } = require('../workspace/authorization');

test('access grants accept supported scopes and create a retry-stable ID', () => {
  const grant = normalizeWorkspaceGrant({
    resourceId: 'resource_1', scope: 'department', subjectId: 'Sales',
    capability: 'edit', effect: 'allow',
  });
  assert.equal(grantDocumentId(grant), grantDocumentId({ ...grant }));
  assert.match(grantDocumentId(grant), /^grant_[a-f0-9]{40}$/);
});

test('access grants reject malformed scopes and capabilities', () => {
  assert.throws(() => normalizeWorkspaceGrant({
    resourceId: 'resource_1', scope: 'all_company', subjectId: 'Sales', capability: 'edit',
  }), /صلاحية الوصول/);
  assert.throws(() => normalizeWorkspaceGrant({
    resourceId: 'resource_1', scope: 'employee', subjectId: 'employee-1', capability: 'owner',
  }), /صلاحية الوصول/);
});

test('a resource-specific denial revokes inherited access immediately', () => {
  const actor = { uid: 'employee-1', role: 'employee', department: 'Sales' };
  const grants = [
    { isActive: true, scope: 'department', subjectId: 'Sales', capability: 'edit', effect: 'allow' },
    { isActive: true, scope: 'employee', subjectId: 'employee-1', capability: 'view', effect: 'deny' },
  ];
  assert.equal(canAccessWorkspaceResource({ actor, grants, capability: 'view' }), false);
});

test('hierarchy import links department, employee, then the employee sheet', () => {
  let id = 0;
  const plan = planWorkspaceSourceImport([
    { id: 'sales', parentExternalId: 'root' },
    { id: 'employee', parentExternalId: 'sales' },
    { id: 'work-sheet', parentExternalId: 'employee' },
  ], new Map(), () => `resource_${++id}`);
  assert.deepEqual(plan.map((item) => item.parentResourceId), [null, 'resource_1', 'resource_2']);
});
