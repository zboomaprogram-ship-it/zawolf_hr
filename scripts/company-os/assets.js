'use strict';

const crypto = require('node:crypto');
const { executeOperation } = require('./operation-gateway');

function requiredText(value, field, max = 160) {
  const text = String(value || '').trim();
  if (!text || text.length > max) { const error = new Error(`Invalid ${field}`); error.code = 'invalid_input'; throw error; }
  return text;
}

function assetPayload(input = {}) {
  return {
    name: requiredText(input.name, 'name'),
    assetTag: requiredText(input.assetTag, 'assetTag', 80),
    category: requiredText(input.category || 'other', 'category', 80),
    serialNumber: String(input.serialNumber || '').trim().slice(0, 160),
    departmentId: String(input.departmentId || '').trim().slice(0, 128),
  };
}

async function assetOperation({ store, actor, operationId, assetId, expectedVersion, operationType, payload, mutation, now = new Date() }) {
  return executeOperation({
    store, actor, operationId, targetId: assetId, operationType, expectedVersion, payload, now,
    currentVersion: async (tx) => (await tx.getAsset(assetId))?.version,
    mutate: async (tx) => {
      const current = await tx.getAsset(assetId);
      if (!current) { const error = new Error('Missing'); error.code = 'not_found'; throw error; }
      const result = await mutation(tx);
      const version = Number(current.version || 0) + 1;
      if (tx.createAssetHistory) await tx.createAssetHistory({ id: `${operationId}:history`, assetId, action: operationType, actorUid: actor.uid, version, createdAt: now });
      return { resourceId: result?.id || assetId, version };
    },
  });
}

async function createAsset({ store, actor, operationId, input, now = new Date() }) {
  const payload = assetPayload(input);
  const assetId = `asset_${crypto.createHash('sha256').update(operationId).digest('hex').slice(0, 24)}`;
  return executeOperation({ store, actor, operationId, targetId: assetId, operationType: 'asset_create', payload, now, mutate: async (tx) => {
    await tx.createAsset({ id: assetId, ...payload, status: 'available', currentEmployeeUid: null, version: 1, createdAt: now, updatedAt: now });
    if (tx.createAssetHistory) await tx.createAssetHistory({ id: `${operationId}:history`, assetId, action: 'asset_create', actorUid: actor.uid, version: 1, createdAt: now });
    return { resourceId: assetId, version: 1 };
  } });
}

async function updateAsset({ store, actor, operationId, assetId, expectedVersion, input, now = new Date() }) {
  const allowed = Object.fromEntries(['name', 'category', 'serialNumber', 'departmentId'].filter((key) => input[key] != null).map((key) => [key, String(input[key]).trim()]));
  if (!Object.keys(allowed).length) { const error = new Error('No changes'); error.code = 'invalid_input'; throw error; }
  return assetOperation({ store, actor, operationId, assetId, expectedVersion, operationType: 'asset_update', payload: allowed, now, mutation: async (tx) => {
    const asset = await tx.getAsset(assetId); if (!asset) { const error = new Error('Missing'); error.code = 'not_found'; throw error; }
    await tx.updateAsset(assetId, { ...allowed, version: Number(asset.version || 0) + 1, updatedAt: now });
  } });
}

function validateMaintenance(input = {}) {
  const cost = Number(input.cost || 0);
  if (!Number.isFinite(cost) || cost < 0) { const error = new Error('Invalid cost'); error.code = 'invalid_input'; throw error; }
  if (cost > 0 && !String(input.costRequestId || '').trim()) { const error = new Error('Cost request required'); error.code = 'cost_request_required'; throw error; }
  return { problem: String(input.problem || '').trim(), provider: String(input.provider || '').trim(), cost, currency: String(input.currency || 'EGP'), costRequestId: input.costRequestId || null };
}

async function assignAsset({ tx, assetId, employeeUid, actorUid, now = new Date(), condition = '' }) {
  const asset = await tx.getAsset(assetId);
  if (!asset || asset.status === 'retired') { const error = new Error('Unavailable asset'); error.code = 'conflict'; throw error; }
  if (asset.status !== 'available' || asset.currentEmployeeUid || await tx.activeAssignment(assetId)) { const error = new Error('Already assigned'); error.code = 'conflict'; throw error; }
  const assignment = { id: `${assetId}:${now.getTime()}`, assetId, employeeUid, assignedBy: actorUid, assignedAt: now, conditionAtHandover: condition };
  await tx.createAssignment(assignment);
  await tx.updateAsset(assetId, { status: 'assigned', currentEmployeeUid: employeeUid, version: Number(asset.version || 0) + 1, updatedAt: now });
  return assignment;
}

async function returnAsset({ tx, assetId, actorUid, now = new Date(), reason = '', condition = '' }) {
  const asset = await tx.getAsset(assetId);
  const assignment = await tx.activeAssignment(assetId);
  if (!asset || !assignment) { const error = new Error('No active assignment'); error.code = 'conflict'; throw error; }
  await tx.completeAssignment(assignment.id, { returnedAt: now, returnedBy: actorUid, returnReason: reason, conditionAtReturn: condition });
  await tx.updateAsset(assetId, { status: 'available', currentEmployeeUid: null, version: Number(asset.version || 0) + 1, updatedAt: now });
  return assignment.id;
}

async function openMaintenance({ tx, assetId, actorUid, input, now = new Date() }) {
  const maintenance = validateMaintenance(input);
  const asset = await tx.getAsset(assetId);
  if (!asset || asset.status === 'retired' || asset.currentEmployeeUid) { const error = new Error('Asset unavailable'); error.code = 'conflict'; throw error; }
  const record = { id: `${assetId}:maintenance:${now.getTime()}`, assetId, openedBy: actorUid, openedAt: now, ...maintenance };
  await tx.createMaintenance(record);
  await tx.updateAsset(assetId, { status: 'maintenance', version: Number(asset.version || 0) + 1, updatedAt: now });
  return record;
}

async function retireAsset({ tx, assetId, now = new Date() }) {
  const asset = await tx.getAsset(assetId);
  if (!asset || asset.currentEmployeeUid || await tx.activeAssignment(assetId)) { const error = new Error('Assigned asset'); error.code = 'conflict'; throw error; }
  await tx.updateAsset(assetId, { status: 'retired', version: Number(asset.version || 0) + 1, retiredAt: now, updatedAt: now });
}

function createFirestoreAssetStore(db) {
  return {
    transact(work) {
      return db.runTransaction(async (transaction) => work({
        async getReceipt(id) { const s = await transaction.get(db.collection('companyOsOperationReceipts').doc(id)); return s.exists ? s.data() : null; },
        async putReceipt(id, value) { transaction.create(db.collection('companyOsOperationReceipts').doc(id), value); },
        async putAudit(id, value) { transaction.create(db.collection('companyOsAuditEvents').doc(id), value); },
        async getAsset(id) { const s = await transaction.get(db.collection('companyOsAssets').doc(id)); return s.exists ? { id: s.id, ...s.data() } : null; },
        async createAsset(value) { transaction.create(db.collection('companyOsAssets').doc(value.id), value); },
        async updateAsset(id, value) { transaction.update(db.collection('companyOsAssets').doc(id), value); },
        async activeAssignment(assetId) { const s = await transaction.get(db.collection('companyOsAssetAssignments').where('assetId', '==', assetId).where('active', '==', true).limit(1)); return s.empty ? null : { id: s.docs[0].id, ...s.docs[0].data() }; },
        async createAssignment(value) { transaction.create(db.collection('companyOsAssetAssignments').doc(value.id), { ...value, active: true }); },
        async completeAssignment(id, value) { transaction.update(db.collection('companyOsAssetAssignments').doc(id), { ...value, active: false }); },
        async createMaintenance(value) { transaction.create(db.collection('companyOsAssetMaintenance').doc(value.id), value); },
        async createAssetHistory(value) { transaction.create(db.collection('companyOsAssetHistory').doc(value.id), value); },
      }));
    },
  };
}

function assignAssetOperation(args) { return assetOperation({ ...args, operationType: 'asset_assign', payload: { employeeUid: args.employeeUid, condition: args.condition || '' }, mutation: (tx) => assignAsset({ tx, assetId: args.assetId, employeeUid: args.employeeUid, actorUid: args.actor.uid, now: args.now, condition: args.condition }) }); }
function returnAssetOperation(args) { return assetOperation({ ...args, operationType: 'asset_return', payload: { reason: args.reason || '', condition: args.condition || '' }, mutation: (tx) => returnAsset({ tx, assetId: args.assetId, actorUid: args.actor.uid, now: args.now, reason: args.reason, condition: args.condition }) }); }
function openMaintenanceOperation(args) { return assetOperation({ ...args, operationType: 'asset_maintenance', payload: validateMaintenance(args.input), mutation: (tx) => openMaintenance({ tx, assetId: args.assetId, actorUid: args.actor.uid, input: args.input, now: args.now }) }); }
function retireAssetOperation(args) { return assetOperation({ ...args, operationType: 'asset_retire', payload: {}, mutation: (tx) => retireAsset({ tx, assetId: args.assetId, now: args.now }) }); }

module.exports = { validateMaintenance, assignAsset, returnAsset, openMaintenance, retireAsset, createAsset, updateAsset, assignAssetOperation, returnAssetOperation, openMaintenanceOperation, retireAssetOperation, createFirestoreAssetStore };
