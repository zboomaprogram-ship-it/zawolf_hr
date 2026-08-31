'use strict';

function organizationDashboardProjection({ units = [], employees = [] }) {
  const activeUnits = units.filter((unit) => unit.archived !== true);
  return {
    sectors: activeUnits.filter((unit) => unit.type === 'sector').length,
    departments: activeUnits.filter((unit) => unit.type === 'department').length,
    managerVacancies: activeUnits.filter((unit) => unit.type === 'department' && !unit.managerUid).length,
    assignedEmployees: employees.filter((employee) => employee.departmentUnitId).length,
    orphanEmployees: employees.filter((employee) => !employee.departmentUnitId).length,
  };
}

const { recordInActorScope } = require('./operations');

async function boundedCount(db, collection, filters = [], predicate = () => true, actor = null) {
  let query = db.collection(collection);
  for (const [field, operator, value] of filters) query = query.where(field, operator, value);
  const snapshot = await query.limit(100).get();
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((record) => !actor || recordInActorScope(actor, record))
    .filter(predicate).length;
}

async function operationsDashboard({ db, actor }) {
  const [openTickets, assignedAssets, expiringLicenses, pendingRequests] = await Promise.all([
    boundedCount(db, 'companyOsTickets', [], (item) => !['resolved', 'closed'].includes(item.status), actor),
    boundedCount(db, 'companyOsAssets', [['status', '==', 'assigned']], () => true, actor),
    boundedCount(db, 'companyOsLicenses', [['status', '==', 'active']], () => true, actor),
    boundedCount(
      db,
      'administrativeRequests',
      [['category', '==', 'company_os']],
      (item) => !['approved', 'rejected', 'closed', 'cancelled'].includes(item.status),
      actor,
    ),
  ]);
  return { openTickets, assignedAssets, expiringLicenses, pendingRequests, scope: actor.role };
}

module.exports = { boundedCount, operationsDashboard, organizationDashboardProjection };
