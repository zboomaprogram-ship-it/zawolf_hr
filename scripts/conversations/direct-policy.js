'use strict';
const C = require('./common');

const value = (user, keys) => keys.map(key => user?.[key]).find(value => typeof value === 'string' && value.trim())?.trim() || '';
const department = user => value(user, ['department', 'departmentName', 'departmentKey']);
const role = user => String(user?.role || '').toLowerCase();
const isActive = user => user?.isActive !== false;
const isAdmin = user => ['super_admin', 'owner', 'admin', 'administrator'].includes(role(user));
const isHr = user => ['hr', 'hr_admin', 'hr_manager'].includes(role(user)) || C.isHrOrAdmin(user || {});
const isManager = user => ['manager', 'general_manager', 'gm', 'ceo', 'coo'].includes(role(user)) || user?.isManager === true || /manager|مدير/i.test(String(user?.position || user?.jobTitle || ''));
const isIt = user => /^(it|information technology)$/i.test(department(user)) || /\bit\b|تقنية المعلومات|تكنولوجيا المعلومات/i.test(`${user?.position || ''} ${user?.jobTitle || ''}`);
function managerIds(user) {
  return new Set([user?.managerId, user?.teamLeaderId, ...(Array.isArray(user?.managerIds) ? user.managerIds : [])].filter(id => typeof id === 'string' && id));
}
function canDirect(actor, target) {
  if (!actor?.uid || !target?.id || actor.uid === target.id || !isActive(actor) || !isActive(target)) return false;
  if (isAdmin(actor) || isHr(actor) || isManager(actor)) return true;
  if (isIt(target) || isHr(target) || isAdmin(target)) return true;
  if (!isManager(target)) return true;
  return managerIds(actor).has(target.id);
}
function departments(users, actor) {
  return [...new Set(users.filter(user => canDirect(actor, user)).map(department).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'ar'));
}
module.exports = { department, isActive, isAdmin, isHr, isManager, isIt, managerIds, canDirect, departments };
