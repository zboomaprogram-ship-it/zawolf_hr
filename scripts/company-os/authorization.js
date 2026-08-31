'use strict';

const ROLE_CAPABILITIES = Object.freeze({
  employee: ['view_portal', 'submit_ticket', 'view_employee'],
  it_support: ['view_portal', 'submit_ticket', 'view_employee', 'manage_tickets', 'manage_assets', 'manage_software'],
  it_manager: ['view_portal', 'submit_ticket', 'view_employee', 'manage_tickets', 'manage_assets', 'manage_software', 'manage_access', 'manage_requests', 'view_operations'],
  finance: ['view_portal', 'submit_ticket', 'view_employee', 'review_finance', 'manage_requests', 'view_operations'],
  manager: ['view_portal', 'submit_ticket', 'view_employee', 'manage_requests', 'view_operations'],
  hr_admin: ['view_portal', 'submit_ticket', 'view_employee', 'manage_requests', 'view_operations'],
  admin: ['view_portal', 'submit_ticket', 'view_employee', 'manage_requests', 'view_operations'],
  super_admin: ['*'],
});

function roleScopes(actor) {
  if (!actor || actor.active !== true) return [];
  if (actor.role === 'super_admin' || actor.role === 'admin' || actor.role === 'hr_admin') return ['company'];
  if (actor.role === 'manager') return ['self', 'team'];
  if (['it_support', 'it_manager', 'finance'].includes(actor.role)) return ['self', 'department'];
  return ['self'];
}

function targetInScope(actor, target) {
  if (!target || target.uid === actor.uid) return true;
  const scopes = roleScopes(actor);
  if (scopes.includes('company')) return true;
  if (scopes.includes('team') && Array.isArray(actor.teamUserIds) && actor.teamUserIds.includes(target.uid)) return true;
  return scopes.includes('department') && actor.departmentId && actor.departmentId === target.departmentId;
}

function authorizeCapability({ actor, capability, target = null }) {
  if (!actor || actor.active !== true || !actor.uid) return false;
  const capabilities = ROLE_CAPABILITIES[actor.role] || [];
  if (!(capabilities.includes('*') || capabilities.includes(capability))) return false;
  return capability !== 'view_employee' || targetInScope(actor, target);
}

async function resolveActiveActor({ db, uid }) {
  const snapshot = await db.collection('users').doc(uid).get();
  const data = snapshot.data?.() || {};
  if (!snapshot.exists || data.isActive !== true) return null;
  const managerIds = Array.from(new Set([
    ...(Array.isArray(data.managerIds) ? data.managerIds : []),
    data.managerId,
    data.directManagerId,
  ].map((value) => String(value || '').trim()).filter(Boolean)));
  return {
    uid,
    role: String(data.operationalRole || data.role || 'employee'),
    departmentId: String(data.departmentId || data.department || ''),
    department: String(data.department || data.departmentId || ''),
    employeeId: String(data.employeeId || data.code || ''),
    displayName: String(data.name || data.displayName || data.email || ''),
    managerIds,
    organizationTreeAdminIds: Array.isArray(data.organizationTreeAdminIds)
      ? data.organizationTreeAdminIds.map(String)
      : [],
    teamUserIds: Array.isArray(data.teamUserIds) ? data.teamUserIds : [],
    capabilities: Array.isArray(data.operationalCapabilities)
      ? data.operationalCapabilities.map(String)
      : Array.isArray(data.capabilities) ? data.capabilities.map(String) : [],
    active: true,
  };
}

module.exports = { ROLE_CAPABILITIES, roleScopes, authorizeCapability, resolveActiveActor };
