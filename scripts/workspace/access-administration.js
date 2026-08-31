'use strict';

const VALID_SCOPES = new Set(['employee', 'team', 'department', 'role', 'resource']);
const VALID_CAPABILITIES = new Set([
  'view', 'download', 'comment', 'edit', 'manage_content', 'manage_access',
]);
const VALID_EFFECTS = new Set(['allow', 'deny']);

function accessValidationError() {
  const error = new Error('بيانات صلاحية الوصول غير صحيحة.');
  error.code = 'validation';
  return error;
}

function normalizeWorkspaceGrant(input = {}) {
  const resourceId = String(input.resourceId || '').trim();
  const scope = String(input.scope || '').trim();
  const subjectId = String(input.subjectId || '').trim();
  const capability = String(input.capability || '').trim();
  const effect = String(input.effect || 'allow').trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(resourceId) ||
      !VALID_SCOPES.has(scope) || !subjectId || subjectId.length > 256 ||
      !VALID_CAPABILITIES.has(capability) || !VALID_EFFECTS.has(effect)) {
    throw accessValidationError();
  }
  return { resourceId, scope, subjectId, capability, effect };
}

function grantDocumentId({ resourceId, scope, subjectId, capability, effect }) {
  const crypto = require('node:crypto');
  const key = `${resourceId}|${scope}|${subjectId}|${capability}|${effect}`;
  return `grant_${crypto.createHash('sha256').update(key).digest('hex').slice(0, 40)}`;
}

module.exports = {
  VALID_SCOPES,
  VALID_CAPABILITIES,
  normalizeWorkspaceGrant,
  grantDocumentId,
};
