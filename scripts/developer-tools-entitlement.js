const DEVELOPER_TOOL_SCOPES = new Set([
  'app_diagnostics',
  'network_diagnostics',
  'release_information',
]);
const MAX_ENTITLEMENT_MS = 7 * 24 * 60 * 60 * 1000;

function normalizeDeveloperToolScopes(input) {
  if (!Array.isArray(input)) return [];
  return [...new Set(input.map((scope) => String(scope || '').trim()))]
    .filter((scope) => DEVELOPER_TOOL_SCOPES.has(scope));
}

function isDeveloperToolsExpiryValid(expiresAt, now = Date.now()) {
  const expiry = expiresAt instanceof Date ? expiresAt.getTime() : Number.NaN;
  return Number.isFinite(expiry) && expiry > now && expiry <= now + MAX_ENTITLEMENT_MS;
}

function isDeveloperToolsEntitlementActive(data, now = Date.now()) {
  if (!data || data.revokedAt != null) return false;
  if (data.permanent === true) return true;
  const expiresAt = data.expiresAt?.toDate?.() || data.expiresAt;
  return isDeveloperToolsExpiryValid(expiresAt, now);
}

module.exports = {
  DEVELOPER_TOOL_SCOPES,
  MAX_ENTITLEMENT_MS,
  normalizeDeveloperToolScopes,
  isDeveloperToolsExpiryValid,
  isDeveloperToolsEntitlementActive,
};
