'use strict';

const COMPANY_OS_FLAGS = new Set([
  'company_os_portal_v1',
  'company_os_it_v1',
  'company_os_requests_v1',
  'company_os_operations_v1',
  'company_os_organization_v1',
  'company_os_multi_tree_v1',
]);

function evaluateCompanyOsFlag(name, config = {}, actorId = '') {
  if (!COMPANY_OS_FLAGS.has(name)) return { enabled: false, reason: 'unknown_flag' };
  const value = config[name];
  const enabled = value?.enabled === true && (value.everyone === true || (actorId && Array.isArray(value.actorIds) && value.actorIds.includes(actorId)));
  return { enabled, reason: enabled ? 'audience_match' : 'disabled_or_outside_audience', legacyFallbackRetained: true };
}

function updateCompanyOsFlag({ name, enabled, actorIds = [], actor, reason, audit }) {
  if (!COMPANY_OS_FLAGS.has(name) || actor?.role !== 'super_admin' || !String(reason || '').trim()) {
    const error = new Error('Not authorized'); error.code = 'access_denied'; throw error;
  }
  const result = { name, enabled: enabled === true, actorIds: [...new Set(actorIds)], legacyFallbackRetained: true };
  audit?.({ action: 'company_os_flag_changed', actorUid: actor.uid, reason: String(reason), result });
  return result;
}

module.exports = { COMPANY_OS_FLAGS, evaluateCompanyOsFlag, updateCompanyOsFlag };
