'use strict';

const clean = value => String(value || '').trim().toLowerCase();

function isLegacyHrAssignment(advance = {}) {
  const assignments = [
    advance.managerId,
    advance.currentApproverId,
    ...(Array.isArray(advance.managerIds) ? advance.managerIds : []),
  ].map(clean);
  return assignments.includes('hr') || assignments.includes('human_resources');
}

// Older advance documents used `pending_manager` with a literal "HR"
// managerId. The app's timeline interpreted the missing route stage as HR,
// but its action guard correctly treated it as a manager-stage document. Give
// that legacy shape one canonical HR stage so the displayed route and the
// authorised reviewer agree.
function legacyHrAdvancePatch(advance = {}) {
  if (String(advance.status || '') !== 'pending_manager') return null;
  if (String(advance.advanceRouteStage || '').trim()) return null;
  if (!isLegacyHrAssignment(advance)) return null;
  return {
    status: 'pending_hr',
    advanceRouteStage: 'hr',
    managerId: 'HR',
    managerName: 'الموارد البشرية',
  };
}

module.exports = { isLegacyHrAssignment, legacyHrAdvancePatch };
