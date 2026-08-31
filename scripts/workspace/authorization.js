const CAPABILITY_ORDER = ['view', 'download', 'comment', 'edit', 'manage_content', 'manage_access'];

function roleKey(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, ' ')
    .replace(/\\s+/g, ' ');
}

function isWorkspaceItManager(actor) {
  if (actor?.isItManager === true) return true;
  if (!['manager', 'it manager'].includes(roleKey(actor?.role))) return false;
  const unit = `${actor.department || ''} ${actor.position || ''}`.toLowerCase();
  return unit.includes('information technology') ||
    /(^|[^a-z])it([^a-z]|$)/.test(unit) ||
    unit.includes('تكنولوجيا المعلومات') ||
    unit.includes('تقنية المعلومات') ||
    unit.includes('قسم تقنية') ||
    unit.includes('قسم it');
}

function isWorkspaceController(actor) {
  const role = String(actor?.role || '').trim().toLowerCase();
  const scope = `${role} ${actor?.department || ''} ${actor?.position || ''} ${actor?.jobTitle || ''}`.toLowerCase();
  return ['super_admin', 'admin', 'administrator', 'owner'].includes(role) ||
    ['super admin', 'system admin', 'system administrator'].includes(roleKey(role)) ||
    scope.includes('مسؤول النظام') || scope.includes('مدير النظام') ||
    scope.includes('إدارة النظام') || scope.includes('ادارة النظام') ||
    isWorkspaceItManager(actor);
}

function capabilityImplies(granted, requested) {
  const index = CAPABILITY_ORDER.indexOf(granted);
  const requestedIndex = CAPABILITY_ORDER.indexOf(requested);
  if (index < 0 || requestedIndex < 0) return false;
  if (granted === 'manage_access') return true;
  if (granted === 'manage_content') return requested !== 'manage_access';
  if (granted === 'edit') return ['view', 'download', 'comment', 'edit'].includes(requested);
  if (granted === 'comment') return ['view', 'comment'].includes(requested);
  return granted === requested || (granted === 'download' && requested === 'view');
}

function grantMatches(actor, grant) {
  if (!grant || grant.isActive !== true) return false;
  const scope = String(grant.scope || 'employee');
  const subjectId = String(grant.subjectId || grant.userId || '');
  const employeeSubjects = [actor?.uid, actor?.email, actor?.employeeId, actor?.employeeCode]
    .map((value) => String(value || '').trim())
    .filter(Boolean);
  return (scope === 'employee' || scope === 'resource') && employeeSubjects.includes(subjectId) ||
    scope === 'department' && subjectId === actor.department ||
    scope === 'role' && subjectId === actor.role ||
    scope === 'team' && Array.isArray(actor.teamIds) && actor.teamIds.includes(subjectId);
}

function canAccessWorkspaceResource({ actor, grants, capability }) {
  if (isWorkspaceController(actor)) return true;
  const relevant = (grants || []).filter((grant) =>
    grantMatches(actor, grant) && capabilityImplies(String(grant.capability || grant.permission || ''), capability),
  );
  if (relevant.some((grant) => String(grant.effect || 'allow') === 'deny')) return false;
  return relevant.some((grant) => String(grant.effect || 'allow') === 'allow');
}

module.exports = {
  capabilityImplies,
  canAccessWorkspaceResource,
  isWorkspaceItManager,
  isWorkspaceController,
};
