'use strict';

function configuredEmployeeApiTokens(env = process.env) {
  return [...new Set([
    env.EMPLOYEE_API_KEY,
    env.NOTIFICATION_DISPATCH_SECRET,
  ].map((value) => String(value || '').trim()).filter(Boolean))];
}

function isEmployeeApiTokenAllowed(token, env = process.env) {
  const candidate = String(token || '').trim();
  return candidate.length > 0 && configuredEmployeeApiTokens(env).includes(candidate);
}

module.exports = {
  configuredEmployeeApiTokens,
  isEmployeeApiTokenAllowed,
};
