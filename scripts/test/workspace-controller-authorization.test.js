const test = require('node:test');
const assert = require('node:assert/strict');
const { isWorkspaceController } = require('../workspace/authorization');

test('active IT managers are controllers by their current role attributes, not employee code', () => {
  assert.equal(
    isWorkspaceController({ role: 'manager', department: 'Information Technology' }),
    true,
  );
  assert.equal(
    isWorkspaceController({ role: 'manager', position: 'مدير تقنية المعلومات' }),
    true,
  );
  assert.equal(
    isWorkspaceController({ role: 'manager', department: 'Marketing', employeeCode: 'IT-400' }),
    false,
  );
});

test('super admins retain controller access and ordinary managers do not', () => {
  assert.equal(isWorkspaceController({ role: 'super_admin' }), true);
  assert.equal(isWorkspaceController({ role: 'manager', department: 'Operations' }), false);
});
