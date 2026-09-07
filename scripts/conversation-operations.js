'use strict';

const ID = /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/;
const MANAGEMENT_ROLES = new Set([
  'team_leader', 'manager', 'hr_admin', 'hr_manager', 'super_admin',
]);
const CROSS_DEPARTMENT_ROLES = new Set([
  'hr', 'hr_admin', 'hr_manager', 'admin', 'administrator', 'owner', 'super_admin',
]);

function safeId(value) {
  const id = String(value || '').trim();
  return ID.test(id) ? id : null;
}

function normalizeMemberIds(actorId, values) {
  const actor = safeId(actorId);
  if (!actor || !Array.isArray(values)) return null;
  const members = [...new Set(values.map(safeId).filter(Boolean))];
  if (!members.includes(actor)) members.push(actor);
  return members.length >= 2 && members.length <= 10 ? members.sort() : null;
}

function isConversationMember(conversation, actorId) {
  return conversation?.state !== 'closed' &&
    Array.isArray(conversation?.memberUserIds) &&
    conversation.memberUserIds.includes(actorId);
}

function normalizeDepartmentName(value) {
  const name = String(value || '').replace(/\s+/g, ' ').trim();
  return name && name.length <= 120 ? name : null;
}

function departmentKey(value) {
  const name = normalizeDepartmentName(value);
  return name ? name.toLocaleLowerCase('ar') : null;
}

function canAccessDepartment(actor, requestedDepartment) {
  const requestedKey = departmentKey(requestedDepartment);
  if (!actor?.uid || !requestedKey) return false;
  if (CROSS_DEPARTMENT_ROLES.has(String(actor.role || '').toLowerCase())) return true;
  return departmentKey(actor.department) === requestedKey;
}

function containsExternalDriveLink(value) {
  return /https?:\/\/(?:drive|docs)\.google\.com\//i.test(String(value || ''));
}

function normalizeMessageInput(input) {
  const operationId = safeId(input?.operationId);
  const body = String(input?.body || '').trim();
  const attachmentResourceIds = Array.isArray(input?.attachmentResourceIds)
    ? [...new Set(input.attachmentResourceIds.map(safeId).filter(Boolean))]
    : [];
  if ((input?.attachmentResourceIds !== undefined && (!Array.isArray(input.attachmentResourceIds) || input.attachmentResourceIds.some((id) => !safeId(id)))) ||
      !operationId || (!body && !attachmentResourceIds.length) || body.length > 4000 ||
      attachmentResourceIds.length > 10 || containsExternalDriveLink(body)) {
    return null;
  }
  return { operationId, body, attachmentResourceIds };
}

function normalizeAttachmentInput(input) {
  const operationId = safeId(input?.operationId);
  const name = String(input?.name || '').trim();
  const mimeType = String(input?.mimeType || '').trim();
  const contentsBase64 = String(input?.contentsBase64 || '').trim();
  if (!operationId || !name || name.length > 160 || !mimeType ||
      mimeType.length > 120 || !contentsBase64 ||
      contentsBase64.length > 14 * 1024 * 1024) return null;
  return { operationId, name, mimeType, contentsBase64 };
}

function canStartConversation({ actor, actorUser, memberUsers }) {
  if (!actor?.uid || !Array.isArray(memberUsers) || memberUsers.length < 2) {
    return false;
  }
  if (memberUsers.some((user) => user?.isActive !== true)) return false;
  const actorRole = String(actor.role || '');
  if (actorRole === 'hr_admin' || actorRole === 'hr_manager' ||
      actorRole === 'super_admin') return true;

  if (actorRole === 'manager' || actorRole === 'team_leader') {
    return memberUsers
      .filter((user) => user.uid !== actor.uid)
      .every((user) =>
        (Array.isArray(user.managerIds) && user.managerIds.includes(actor.uid)) ||
        user.teamLeaderId === actor.uid || MANAGEMENT_ROLES.has(user.role));
  }

  const allowedManagerIds = new Set([
    ...(Array.isArray(actorUser?.managerIds) ? actorUser.managerIds : []),
    actorUser?.managerId,
    actorUser?.teamLeaderId,
  ].filter(Boolean));
  return memberUsers
    .filter((user) => user.uid !== actor.uid)
    .every((user) => MANAGEMENT_ROLES.has(user.role) &&
      (user.role.startsWith('hr_') || user.role === 'super_admin' ||
       allowedManagerIds.has(user.uid)));
}

module.exports = {
  CROSS_DEPARTMENT_ROLES,
  MANAGEMENT_ROLES,
  canAccessDepartment,
  departmentKey,
  normalizeDepartmentName,
  safeId,
  normalizeMemberIds,
  isConversationMember,
  containsExternalDriveLink,
  normalizeMessageInput,
  normalizeAttachmentInput,
  canStartConversation,
};
