// Production accounts have used both the legacy role names and the shorter
// names below.  Authorization must not depend on letter case or on which
// administrative label was used when the account was created.
const HR_ROLES = new Set([
  'hr',
  'hr_admin',
  'hr_manager',
  'admin',
  'administrator',
  'super_admin',
  'owner',
]);

function isHrOrAdmin(actor) {
  const role = String(actor?.role || '').trim().toLowerCase();
  return Boolean(actor?.active !== false && HR_ROLES.has(role));
}

function canManageDeveloperTools(actor) {
  return isHrOrAdmin(actor);
}

function canManageOperationalVisibility(actor) {
  return isHrOrAdmin(actor);
}

function canReviewAttendanceSecurity(actor) {
  return isHrOrAdmin(actor);
}

function canManageSalesMappings(actor) {
  return isHrOrAdmin(actor);
}

function canViewDiagnostics(actor) {
  return isHrOrAdmin(actor);
}

function isSelfOrAuthorizedTeamMember(actor, targetUserId) {
  if (!actor?.uid || !targetUserId) return false;
  return actor.uid === targetUserId || isHrOrAdmin(actor) ||
    (actor.role === 'manager' && Array.isArray(actor.teamUserIds) && actor.teamUserIds.includes(targetUserId));
}

function auditActorContext(actor) {
  return {
    actorId: String(actor?.uid || ''),
    actorRole: String(actor?.role || ''),
  };
}

module.exports = {
  isHrOrAdmin,
  canManageDeveloperTools,
  canManageOperationalVisibility,
  canReviewAttendanceSecurity,
  canManageSalesMappings,
  canViewDiagnostics,
  isSelfOrAuthorizedTeamMember,
  auditActorContext,
};
