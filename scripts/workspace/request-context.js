const crypto = require('node:crypto');

function asSafeOperationId(value) {
  const id = String(value || '').trim();
  return /^[A-Za-z0-9_-]{12,128}$/.test(id) ? id : null;
}

function requestContext(req = {}) {
  const headers = req.headers || {};
  const operationId = asSafeOperationId(headers['x-workspace-operation-id']);
  return {
    correlationId: operationId || crypto.randomUUID(),
    operationId,
  };
}

module.exports = { asSafeOperationId, requestContext };
