'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { COMPANY_OS_FLAGS, evaluateCompanyOsFlag, updateCompanyOsFlag } = require('../company-os/feature-flags');

test('all Company OS flags fail closed and audiences are actor-specific', () => {
  for (const flag of COMPANY_OS_FLAGS) assert.equal(evaluateCompanyOsFlag(flag, {}, 'actor-1').enabled, false);
  const config = { company_os_portal_v1: { enabled: true, actorIds: ['pilot-1'] } };
  assert.equal(evaluateCompanyOsFlag('company_os_portal_v1', config, 'pilot-1').enabled, true);
  assert.equal(evaluateCompanyOsFlag('company_os_portal_v1', config, 'actor-2').enabled, false);
});

test('audited rollback disables a slice without removing its fallback', () => {
  const events = [];
  const result = updateCompanyOsFlag({
    name: 'company_os_it_v1',
    enabled: false,
    actorIds: [],
    actor: { uid: 'owner-1', role: 'super_admin' },
    reason: 'pilot rollback',
    audit: (event) => events.push(event),
  });
  assert.equal(result.enabled, false);
  assert.equal(result.legacyFallbackRetained, true);
  assert.equal(events.length, 1);
});

