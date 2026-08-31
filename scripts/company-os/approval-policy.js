'use strict';

const COST_TYPES = new Set(['advance', 'reimbursement', 'custody', 'payment', 'asset_purchase', 'repair_maintenance', 'software_license', 'other_expense']);
const NON_COST_TYPES = new Set(['access', 'it_access']);

function classifyRequest(requestType) {
  const type = String(requestType || '').trim().toLowerCase();
  if (COST_TYPES.has(type)) return { type, costBearing: true };
  if (NON_COST_TYPES.has(type)) return { type, costBearing: false };
  const error = new Error('Unknown request type'); error.code = 'invalid_input'; throw error;
}

function materializeApprovalPlan({ requestId, requestType, managerUid, specialistRole, ownerPolicy, createdAt = new Date() }) {
  const classification = classifyRequest(requestType);
  // IT requests are intentionally manager-led.  HR may read and support a
  // request, but must never become its implicit approver.  When an employee
  // has no manager, send the ticket directly to IT instead of creating an
  // un-actionable approval stage.
  const stages = [];
  if (managerUid) {
    stages.push({ type: 'manager', assigneeUid: managerUid, required: true, status: 'pending' });
  } else if (!specialistRole) {
    const error = new Error('Manager unavailable'); error.code = 'access_denied'; throw error;
  }
  if (specialistRole) stages.push({ type: 'specialist', role: specialistRole, required: true, status: 'pending' });
  if (classification.costBearing) {
    if (!ownerPolicy?.ownerUid || !ownerPolicy?.version) {
      const error = new Error('Owner unavailable'); error.code = 'owner_unavailable'; throw error;
    }
    stages.push({ type: 'finance', role: 'finance', required: true, status: 'pending' });
    stages.push({ type: 'owner', assigneeUid: ownerPolicy.ownerUid, required: true, status: 'pending' });
    stages.push({ type: 'payment', role: 'finance', required: true, status: 'pending' });
  }
  stages.push({ type: 'closure', role: specialistRole || 'admin', required: true, status: 'pending' });
  return { requestId, policyVersion: ownerPolicy?.version || 1, costBearing: classification.costBearing, stages, createdAt };
}

module.exports = { COST_TYPES, classifyRequest, materializeApprovalPlan };
