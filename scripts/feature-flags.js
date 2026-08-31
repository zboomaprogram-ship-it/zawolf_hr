const PHASE007_FLAGS = new Set([
  'employee_operations_v2', 'work_outcomes_v2', 'notification_operations_v2',
  'operational_visibility_v2', 'sales_indicators_v2', 'diagnostics_v2',
  'developer_tools_v2', 'employee_assistant_v2', 'conversations_v2',
]);
const { COMPANY_OS_FLAGS, evaluateCompanyOsFlag } = require('./company-os/feature-flags');
const ATTENDANCE_FLAGS = new Set(['attendance_multi_location_v1']);

function isPhase007FlagEnabled(name, config = {}, actorId = '') {
  if (!PHASE007_FLAGS.has(name)) return false;
  const flag = config[name];
  if (!flag || flag.enabled !== true) return false;
  return flag.everyone === true || (Array.isArray(flag.actorIds) && flag.actorIds.includes(actorId));
}

module.exports = {
  PHASE007_FLAGS,
  COMPANY_OS_FLAGS,
  ATTENDANCE_FLAGS,
  isPhase007FlagEnabled,
  isCompanyOsFlagEnabled(name, config = {}, actorId = '') {
    return evaluateCompanyOsFlag(name, config, actorId).enabled;
  },
  isAttendanceFlagEnabled(name, config = {}, actorId = '') {
    if (!ATTENDANCE_FLAGS.has(name)) return false;
    const flag = config[name];
    if (flag === true) return true;
    if (!flag || flag.enabled !== true) return false;
    return flag.everyone === true ||
      (Array.isArray(flag.actorIds) && flag.actorIds.includes(actorId));
  },
};
