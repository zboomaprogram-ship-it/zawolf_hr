'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { stableLegacyId, buildMigrationPlan } = require('../company-os/migrate-organization-structure');

test('organization migration is deterministic, dry-run first, and reports unresolved data', () => {
  assert.equal(stableLegacyId('sector', 'sales'), stableLegacyId('sector', 'sales'));
  const plan = buildMigrationPlan({
    divisions: [{ id: 'sales', name: 'المبيعات' }],
    departments: [{ id: 'd1', name: 'مبيعات', divisionId: 'sales', managerUid: 'missing' }],
    users: [{ uid: 'u1', isActive: true, department: 'غير موجود' }],
  });
  assert.equal(plan.dryRun, true);
  assert.equal(plan.units.length, 2);
  assert.deepEqual(plan.issues.map((item) => item.code).sort(), ['orphan_employee', 'unresolved_manager']);
});
