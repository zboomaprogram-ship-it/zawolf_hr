'use strict';

const crypto = require('node:crypto');
const { executeOperation } = require('./operation-gateway');

async function assignSeat({ tx, licenseId, employeeUid, actorUid, now = new Date() }) {
  const license = await tx.getLicense(licenseId);
  if (!license || license.status !== 'active') { const error = new Error('Inactive license'); error.code = 'conflict'; throw error; }
  if (await tx.activeSeat(licenseId, employeeUid)) { const error = new Error('Duplicate seat'); error.code = 'conflict'; throw error; }
  if (Number(license.usedSeats || 0) >= Number(license.totalSeats || 0)) { const error = new Error('No capacity'); error.code = 'capacity_reached'; throw error; }
  const assignment = { id: `${licenseId}:${employeeUid}`, licenseId, employeeUid, assignedBy: actorUid, assignedAt: now };
  await tx.createSeat(assignment);
  await tx.updateLicense(licenseId, { usedSeats: Number(license.usedSeats || 0) + 1, version: Number(license.version || 0) + 1, updatedAt: now });
  return assignment;
}

async function revokeSeat({ tx, licenseId, employeeUid, now = new Date() }) {
  const license = await tx.getLicense(licenseId);
  const assignment = await tx.activeSeat(licenseId, employeeUid);
  if (!license || !assignment) { const error = new Error('Seat missing'); error.code = 'conflict'; throw error; }
  await tx.revokeSeat(assignment.id, { revokedAt: now });
  await tx.updateLicense(licenseId, { usedSeats: Math.max(0, Number(license.usedSeats || 0) - 1), version: Number(license.version || 0) + 1, updatedAt: now });
  return assignment.id;
}

function licensePayload(input = {}) {
  const name = String(input.name || '').trim();
  const totalSeats = Number(input.totalSeats);
  if (!name || name.length > 160 || !Number.isInteger(totalSeats) || totalSeats < 1 || totalSeats > 100000) { const error = new Error('Invalid license'); error.code = 'invalid_input'; throw error; }
  return { name, vendor: String(input.vendor || '').trim().slice(0, 160), totalSeats, renewalAt: input.renewalAt || null, costRequestId: input.costRequestId || null };
}

async function licenseOperation({ store, actor, operationId, licenseId, expectedVersion, operationType, payload, mutation, now = new Date() }) {
  return executeOperation({ store, actor, operationId, targetId: licenseId, operationType, expectedVersion, payload, now,
    currentVersion: async (tx) => (await tx.getLicense(licenseId))?.version,
    mutate: async (tx) => {
      const current = await tx.getLicense(licenseId); if (!current) { const error = new Error('Missing'); error.code = 'not_found'; throw error; }
      const result = await mutation(tx); const version = Number(current.version || 0) + 1;
      if (tx.createLicenseHistory) await tx.createLicenseHistory({ id: `${operationId}:history`, licenseId, action: operationType, actorUid: actor.uid, version, createdAt: now });
      return { resourceId: result?.id || licenseId, version };
    } });
}

async function createLicense({ store, actor, operationId, input, now = new Date() }) {
  const payload = licensePayload(input); const licenseId = `license_${crypto.createHash('sha256').update(operationId).digest('hex').slice(0, 24)}`;
  return executeOperation({ store, actor, operationId, targetId: licenseId, operationType: 'license_create', payload, now, mutate: async (tx) => {
    await tx.createLicense({ id: licenseId, ...payload, usedSeats: 0, status: 'active', version: 1, createdAt: now, updatedAt: now });
    if (tx.createLicenseHistory) await tx.createLicenseHistory({ id: `${operationId}:history`, licenseId, action: 'license_create', actorUid: actor.uid, version: 1, createdAt: now });
    return { resourceId: licenseId, version: 1 };
  } });
}

async function updateLicense({ store, actor, operationId, licenseId, expectedVersion, input, now = new Date() }) {
  const changes = Object.fromEntries(['name', 'vendor', 'renewalAt', 'status', 'totalSeats'].filter((key) => input[key] != null).map((key) => [key, key === 'totalSeats' ? Number(input[key]) : input[key]]));
  return licenseOperation({ store, actor, operationId, licenseId, expectedVersion, operationType: 'license_update', payload: changes, now, mutation: async (tx) => {
    const license = await tx.getLicense(licenseId); if (!license) { const error = new Error('Missing'); error.code = 'not_found'; throw error; }
    if (changes.totalSeats != null && (!Number.isInteger(changes.totalSeats) || changes.totalSeats < Number(license.usedSeats || 0))) { const error = new Error('Capacity'); error.code = 'capacity_reached'; throw error; }
    await tx.updateLicense(licenseId, { ...changes, version: Number(license.version || 0) + 1, updatedAt: now });
  } });
}

function createFirestoreSoftwareStore(db) {
  return { transact(work) { return db.runTransaction(async (transaction) => work({
    async getReceipt(id) { const s = await transaction.get(db.collection('companyOsOperationReceipts').doc(id)); return s.exists ? s.data() : null; },
    async putReceipt(id, value) { transaction.create(db.collection('companyOsOperationReceipts').doc(id), value); },
    async putAudit(id, value) { transaction.create(db.collection('companyOsAuditEvents').doc(id), value); },
    async getLicense(id) { const s = await transaction.get(db.collection('companyOsLicenses').doc(id)); return s.exists ? { id: s.id, ...s.data() } : null; },
    async createLicense(value) { transaction.create(db.collection('companyOsLicenses').doc(value.id), value); },
    async updateLicense(id, value) { transaction.update(db.collection('companyOsLicenses').doc(id), value); },
    async activeSeat(licenseId, employeeUid) { const s = await transaction.get(db.collection('companyOsLicenseSeats').where('licenseId', '==', licenseId).where('employeeUid', '==', employeeUid).where('active', '==', true).limit(1)); return s.empty ? null : { id: s.docs[0].id, ...s.docs[0].data() }; },
    async createSeat(value) { transaction.create(db.collection('companyOsLicenseSeats').doc(value.id), { ...value, active: true }); },
    async revokeSeat(id, value) { transaction.update(db.collection('companyOsLicenseSeats').doc(id), { ...value, active: false }); },
    async createLicenseHistory(value) { transaction.create(db.collection('companyOsLicenseHistory').doc(value.id), value); },
  })); } };
}

function assignSeatOperation(args) { return licenseOperation({ ...args, operationType: 'license_assign_seat', payload: { employeeUid: args.employeeUid }, mutation: (tx) => assignSeat({ tx, licenseId: args.licenseId, employeeUid: args.employeeUid, actorUid: args.actor.uid, now: args.now }) }); }
function revokeSeatOperation(args) { return licenseOperation({ ...args, operationType: 'license_revoke_seat', payload: { employeeUid: args.employeeUid }, mutation: (tx) => revokeSeat({ tx, licenseId: args.licenseId, employeeUid: args.employeeUid, now: args.now }) }); }

module.exports = { assignSeat, revokeSeat, createLicense, updateLicense, assignSeatOperation, revokeSeatOperation, createFirestoreSoftwareStore };
