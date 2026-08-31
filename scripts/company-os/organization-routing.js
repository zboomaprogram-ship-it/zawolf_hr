'use strict';

function materializeApprovalPlan({ requesterUid, managerUid, createdAt = new Date().toISOString() }) {
  const plan = {
    requesterUid,
    createdAt,
    source: 'organization_projection',
    steps: [{ order: 1, role: 'manager', assigneeUid: managerUid, status: 'pending' }],
  };
  Object.freeze(plan.steps[0]); Object.freeze(plan.steps); return Object.freeze(plan);
}

function refreshFutureRoutingProjection({ employeeUid, managerUid, departmentId }) {
  return Object.freeze({ employeeUid, managerUid: managerUid || null, departmentId: departmentId || null, effectiveForFutureRequestsOnly: true });
}

module.exports = { materializeApprovalPlan, refreshFutureRoutingProjection };
