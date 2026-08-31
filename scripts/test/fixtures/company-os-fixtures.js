'use strict';

const identities = Object.freeze({
  employee: { uid: 'employee-1', role: 'employee', departmentId: 'engineering', managerId: 'manager-1', active: true },
  itSupport: { uid: 'it-support-1', role: 'it_support', departmentId: 'it', active: true },
  itManager: { uid: 'it-manager-1', role: 'it_manager', departmentId: 'it', active: true },
  finance: { uid: 'finance-1', role: 'finance', departmentId: 'finance', active: true },
  manager: { uid: 'manager-1', role: 'manager', departmentId: 'engineering', teamUserIds: ['employee-1'], active: true },
  admin: { uid: 'admin-1', role: 'hr_admin', active: true },
  superAdmin: { uid: 'super-admin-1', role: 'super_admin', active: true },
  inactive: { uid: 'inactive-1', role: 'employee', active: false },
  outOfScope: { uid: 'employee-2', role: 'employee', departmentId: 'sales', active: true },
});

const requestTypes = Object.freeze([
  'access', 'advance', 'reimbursement', 'custody', 'payment',
  'asset_purchase', 'maintenance', 'software_license', 'other_expense',
]);

module.exports = { identities, requestTypes };

