'use strict';

const crypto = require('node:crypto');
const { buildAuditEvent } = require('./audit');
const { validateOperationEnvelope } = require('./safe-errors');

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  return JSON.stringify(value);
}

function payloadHash(payload) { return crypto.createHash('sha256').update(stableJson(payload || {})).digest('hex'); }

async function executeOperation({ store, operationId, actor, operationType, targetId, payload = {}, expectedVersion = null, currentVersion, mutate, now = new Date() }) {
  validateOperationEnvelope({ operationId, expectedVersion });
  if (!actor?.uid || !operationType || !targetId) { const error = new Error('Invalid operation'); error.code = 'invalid_input'; throw error; }
  const hash = payloadHash(payload);
  return store.transact(async (tx) => {
    const existing = tx.getReceipt
      ? await tx.getReceipt(operationId)
      : tx.receipts.get(operationId);
    if (existing) {
      if (existing.actorUid !== actor.uid || existing.operationType !== operationType || existing.payloadHash !== hash) {
        const error = new Error('Operation conflict'); error.code = 'conflict'; throw error;
      }
      return existing.result;
    }
    if (expectedVersion != null && currentVersion && Number(await currentVersion(tx)) !== Number(expectedVersion)) {
      const error = new Error('Version conflict'); error.code = 'conflict'; throw error;
    }
    const result = { ok: true, operationId, status: 'saved', ...(await mutate(tx)) };
    const receipt = { actorUid: actor.uid, operationType, payloadHash: hash, result, createdAt: now };
    const audit = buildAuditEvent({ operationId, actor, action: operationType, targetType: operationType.split('_')[0], targetId, safeAfter: result, now });
    if (tx.putReceipt) await tx.putReceipt(operationId, receipt);
    else tx.receipts.set(operationId, receipt);
    if (tx.putAudit) await tx.putAudit(operationId, audit);
    else tx.audits.set(operationId, audit);
    return result;
  });
}

function createFirestoreOperationStore(db) {
  return {
    transact(work) {
      return db.runTransaction(async (transaction) => work({
        transaction,
        async getReceipt(operationId) {
          const snapshot = await transaction.get(db.collection('companyOsOperationReceipts').doc(operationId));
          return snapshot.exists ? snapshot.data() : null;
        },
        async putReceipt(operationId, receipt) {
          transaction.create(db.collection('companyOsOperationReceipts').doc(operationId), receipt);
        },
        async putAudit(operationId, audit) {
          transaction.create(db.collection('companyOsAuditEvents').doc(operationId), audit);
        },
      }));
    },
  };
}

module.exports = { executeOperation, createFirestoreOperationStore, payloadHash, stableJson };
