'use strict';
const C = require('./common');

const value = (user, keys) => keys.map(key => user?.[key]).find(value => typeof value === 'string' && value.trim())?.trim() || '';
const department = user => value(user, ['department', 'departmentName', 'departmentKey']);
const role = user => String(user?.role || '').toLowerCase();
const isActive = user => user?.isActive !== false;
const isAdmin = user => ['super_admin', 'owner', 'admin', 'administrator'].includes(role(user));
// Keep HR distinct from system administrators for employee direct messages.
// The shared authorization helper intentionally treats admins as HR for
// administrative operations, which is broader than this contact policy.
const isHr = user => ['hr', 'hr_admin', 'hr_manager'].includes(role(user));
const isManager = user => ['manager', 'general_manager', 'gm', 'ceo', 'coo'].includes(role(user)) || user?.isManager === true || /manager|مدير/i.test(String(user?.position || user?.jobTitle || ''));
const isIt = user => /^(it|information technology)$/i.test(department(user)) || /\bit\b|تقنية المعلومات|تكنولوجيا المعلومات/i.test(`${user?.position || ''} ${user?.jobTitle || ''}`);
function managerIds(user) {
  return new Set([user?.managerId, user?.teamLeaderId, ...(Array.isArray(user?.managerIds) ? user.managerIds : [])].filter(id => typeof id === 'string' && id));
}
let cachedPolicy = null;
let lastPolicyFetch = 0;

async function loadPolicy(db) {
  const now = Date.now();
  if (cachedPolicy && now - lastPolicyFetch < 60000) {
    return cachedPolicy;
  }
  try {
    if (db && typeof db.collection === 'function') {
      const doc = await db.collection('publicConfig').doc('chatPolicy').get();
      if (doc.exists) {
        cachedPolicy = doc.data() || {};
        lastPolicyFetch = now;
        return cachedPolicy;
      }
      const compDoc = await db.collection('companies').doc('zawolf').get();
      if (compDoc.exists && compDoc.data()?.chatPolicy) {
        cachedPolicy = compDoc.data().chatPolicy || {};
        lastPolicyFetch = now;
        return cachedPolicy;
      }
    }
  } catch (_) {}
  return cachedPolicy || {};
}

function canDirect(actor, target, policy = {}) {
  if (!actor?.uid || !target?.id || actor.uid === target.id || !isActive(actor) || !isActive(target)) return false;
  if (isAdmin(actor) || isHr(actor) || isManager(actor)) return true;

  // Actor is a normal employee:
  // 1. Direct Manager:
  if (managerIds(actor).has(target.id)) {
    return policy.employeeCanChatWithDirectManager !== false;
  }
  // 2. HR:
  if (isHr(target)) {
    return policy.employeeCanChatWithHr !== false;
  }
  // 3. IT:
  if (isIt(target)) {
    return policy.employeeCanChatWithIt !== false;
  }
  // 4. Other Manager:
  if (isManager(target)) {
    return policy.employeeCanChatWithOtherManagers === true;
  }
  // 5. Admin / Super Admin:
  if (isAdmin(target)) {
    return policy.employeeCanChatWithSuperAdmin === true;
  }
  // 6. Peers (normal employees who are not manager, admin, or HR):
  return policy.employeeCanChatWithPeers !== false;
}
function departments(users, actor, policy = {}) {
  return [...new Set(users.filter(user => canDirect(actor, user, policy)).map(department).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'ar'));
}
module.exports = { department, isActive, isAdmin, isHr, isManager, isIt, managerIds, canDirect, departments, loadPolicy };

