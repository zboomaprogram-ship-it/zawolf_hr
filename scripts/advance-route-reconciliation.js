'use strict';

const clean = value => String(value || '').trim().toLowerCase();

function hasManagerDecision(advance = {}) {
  const trail = Array.isArray(advance.managerApprovalTrail)
    ? advance.managerApprovalTrail
    : [];
  if (trail.length > 0) return true;

  const history = Array.isArray(advance.approvalHistory)
    ? advance.approvalHistory
    : [];
  return history.some((entry) => clean(entry?.stage) === 'manager');
}

// The approved advance route is HR -> CEO -> Accounts. Older clients created
// a new advance as `pending_manager` but omitted `advanceRouteStage`; that
// made the UI show the HR route while withholding HR's action controls. Only
// an untouched, unstaged request is safe to repair: explicit CEO/Accounts
// stages and anything a manager already reviewed retain their current route.
function legacyHrAdvancePatch(advance = {}) {
  if (String(advance.status || '') !== 'pending_manager') return null;
  if (String(advance.advanceRouteStage || '').trim()) return null;
  if (hasManagerDecision(advance)) return null;
  return {
    status: 'pending_hr',
    advanceRouteStage: 'hr',
    managerId: 'HR',
    managerName: 'الموارد البشرية',
  };
}

module.exports = { hasManagerDecision, legacyHrAdvancePatch };
