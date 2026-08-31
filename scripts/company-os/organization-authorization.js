'use strict';

const MANAGE_CAPABILITY = 'organization_structure_manage';
const DEFAULT_MANAGE_ROLES = new Set(['hr', 'hr_admin', 'admin', 'super_admin']);

function capabilitiesOf(actor) {
  return new Set([
    ...(Array.isArray(actor?.capabilities) ? actor.capabilities : []),
    ...(Array.isArray(actor?.operationalCapabilities) ? actor.operationalCapabilities : []),
  ].map(String));
}

function canReadOrganization(actor) {
  return Boolean(actor?.uid && actor.active === true);
}

function canManageOrganization(actor) {
  if (!canReadOrganization(actor)) return false;
  return capabilitiesOf(actor).has(MANAGE_CAPABILITY)
    || DEFAULT_MANAGE_ROLES.has(String(actor.role || '').toLowerCase());
}

function canManageOrganizationTree(actor, treeId) {
  if (canManageOrganization(actor)) return true;
  const cleanTreeId = String(treeId || '').trim();
  return cleanTreeId.length > 0
    && Array.isArray(actor?.organizationTreeAdminIds)
    && actor.organizationTreeAdminIds.map(String).includes(cleanTreeId);
}

function requireOrganizationRead(actor) {
  if (!canReadOrganization(actor)) {
    const error = new Error('Organization read denied'); error.code = 'access_denied'; throw error;
  }
}

function requireOrganizationManage(actor) {
  if (!canManageOrganization(actor)) {
    const error = new Error('Organization write denied'); error.code = 'access_denied'; throw error;
  }
}

function requireOrganizationTreeManage(actor, treeId) {
  if (!canManageOrganizationTree(actor, treeId)) {
    const error = new Error('Organization tree write denied'); error.code = 'access_denied'; throw error;
  }
}

module.exports = {
  MANAGE_CAPABILITY,
  canReadOrganization,
  canManageOrganization,
  canManageOrganizationTree,
  requireOrganizationRead,
  requireOrganizationManage,
  requireOrganizationTreeManage,
};
