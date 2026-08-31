'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { validateTicketTransition, slaDueAt, assignTicket } = require('../company-os/tickets');
const { stripPrivateNotes } = require('../company-os/private-notes');
const { assignAsset, returnAsset, openMaintenance, retireAsset, assignAssetOperation } = require('../company-os/assets');
const { assignSeat, revokeSeat } = require('../company-os/software');
const { authorizeCapability } = require('../company-os/authorization');

test('ticket lifecycle and SLA are deterministic and fail closed', () => {
  assert.equal(validateTicketTransition('new', 'assigned'), 'assigned');
  assert.throws(() => validateTicketTransition('new', 'resolved'), (error) => error.code === 'conflict');
  const now = new Date('2026-08-24T00:00:00Z');
  assert.equal(slaDueAt('critical', now).toISOString(), '2026-08-24T02:00:00.000Z');
});

test('private notes never survive employee/search/export serialization', () => {
  assert.deepEqual(stripPrivateNotes({ id: 't1', privateNotes: [{ body: 'secret' }], nested: { privateNote: 'secret', visible: true } }), { id: 't1', nested: { visible: true } });
});

test('IT capabilities fail closed for employee and inactive actors', () => {
  assert.equal(authorizeCapability({ actor: { uid: 'it1', role: 'it_support', active: true }, capability: 'manage_tickets' }), true);
  assert.equal(authorizeCapability({ actor: { uid: 'u1', role: 'employee', active: true }, capability: 'manage_tickets' }), false);
  assert.equal(authorizeCapability({ actor: { uid: 'it1', role: 'it_manager', active: false }, capability: 'manage_assets' }), false);
});

function operationStore({ ticket = null, asset = null } = {}) {
  const receipts = new Map(); const audits = new Map(); const histories = [];
  let currentTicket = ticket; let currentAsset = asset; let assignment = null;
  let transactionTail = Promise.resolve();
  const tx = {
    receipts, audits, histories,
    async getReceipt(id) { return receipts.get(id) || null; },
    async putReceipt(id, value) { receipts.set(id, value); },
    async putAudit(id, value) { audits.set(id, value); },
    async getTicket() { return currentTicket; },
    async updateTicket(_id, value) { currentTicket = { ...currentTicket, ...value }; },
    async createTicketHistory(value) { histories.push(Object.freeze({ ...value })); },
    async getAsset() { return currentAsset; },
    async activeAssignment() { return assignment?.returnedAt ? null : assignment; },
    async createAssignment(value) { assignment = value; },
    async updateAsset(_id, value) { currentAsset = { ...currentAsset, ...value }; },
    async createAssetHistory(value) { histories.push(Object.freeze({ ...value })); },
  };
  return {
    tx, receipts, audits, histories,
    get ticket() { return currentTicket; },
    get asset() { return currentAsset; },
    async transact(work) {
      const result = transactionTail.then(() => work(tx));
      transactionTail = result.catch(() => {});
      return result;
    },
  };
}

test('ticket retry returns one receipt/history and payload reuse conflicts', async () => {
  const store = operationStore({ ticket: { id: 't1', status: 'new', version: 1 } });
  const input = { store, actor: { uid: 'it1' }, operationId: 'ticket-op-0001', ticketId: 't1', expectedVersion: 1, assigneeUid: 'it2' };
  const first = await assignTicket(input);
  const retry = await assignTicket(input);
  assert.deepEqual(retry, first);
  assert.equal(store.ticket.version, 2);
  assert.equal(store.receipts.size, 1);
  assert.equal(store.audits.size, 1);
  assert.equal(store.histories.length, 1);
  await assert.rejects(assignTicket({ ...input, assigneeUid: 'it3' }), (error) => error.code === 'conflict');
});

test('asset assignment is atomic under retry and retains immutable history', async () => {
  const store = operationStore({ asset: { id: 'a1', status: 'available', currentEmployeeUid: null, version: 1 } });
  const input = { store, actor: { uid: 'it1' }, operationId: 'asset-op-0001', assetId: 'a1', expectedVersion: 1, employeeUid: 'u1', now: new Date('2026-08-24T08:00:00Z') };
  await Promise.all([assignAssetOperation(input), assignAssetOperation(input)]);
  assert.equal(store.asset.currentEmployeeUid, 'u1');
  assert.equal(store.asset.version, 2);
  assert.equal(store.histories.length, 1);
  assert.equal(store.receipts.size, 1);
  assert.equal(Object.isFrozen(store.histories[0]), true);
});

function assetTx(asset) {
  let assignment = null;
  const history = [];
  return {
    history,
    get value() { return asset; },
    async getAsset() { return asset; },
    async activeAssignment() { return assignment?.returnedAt ? null : assignment; },
    async createAssignment(value) { assignment = value; history.push({ ...value }); },
    async completeAssignment(_id, changes) { Object.assign(assignment, changes); Object.assign(history[0], changes); },
    async updateAsset(_id, changes) { asset = { ...asset, ...changes }; },
    async createMaintenance(value) { history.push(value); },
  };
}

test('asset has one active assignment, immutable history, and safe return', async () => {
  const tx = assetTx({ id: 'a1', status: 'available', currentEmployeeUid: null, version: 1 });
  await assignAsset({ tx, assetId: 'a1', employeeUid: 'u1', actorUid: 'it1', now: new Date('2026-08-24T08:00:00Z') });
  await assert.rejects(assignAsset({ tx, assetId: 'a1', employeeUid: 'u2', actorUid: 'it1' }), (error) => error.code === 'conflict');
  await returnAsset({ tx, assetId: 'a1', actorUid: 'it1', reason: 'upgrade' });
  assert.equal(tx.value.status, 'available');
  assert.equal(tx.history[0].employeeUid, 'u1');
  await retireAsset({ tx, assetId: 'a1' });
  assert.equal(tx.value.status, 'retired');
});

test('maintenance with cost requires approved cost-request reference', async () => {
  const tx = assetTx({ id: 'a1', status: 'available', currentEmployeeUid: null, version: 1 });
  await assert.rejects(openMaintenance({ tx, assetId: 'a1', actorUid: 'it1', input: { problem: 'screen', cost: 100 } }), (error) => error.code === 'cost_request_required');
  await openMaintenance({ tx, assetId: 'a1', actorUid: 'it1', input: { problem: 'screen', cost: 100, costRequestId: 'r1' } });
  assert.equal(tx.value.status, 'maintenance');
});

function licenseTx(license) {
  const seats = new Map();
  return {
    get value() { return license; },
    async getLicense() { return license; },
    async activeSeat(id, uid) { const seat = seats.get(`${id}:${uid}`); return seat?.revokedAt ? null : seat; },
    async createSeat(seat) { seats.set(seat.id, seat); },
    async revokeSeat(id, changes) { Object.assign(seats.get(id), changes); },
    async updateLicense(_id, changes) { license = { ...license, ...changes }; },
  };
}

test('software capacity, duplicate assignment and revoke are protected', async () => {
  const tx = licenseTx({ id: 'l1', status: 'active', totalSeats: 1, usedSeats: 0, version: 1 });
  await assignSeat({ tx, licenseId: 'l1', employeeUid: 'u1', actorUid: 'it1' });
  await assert.rejects(assignSeat({ tx, licenseId: 'l1', employeeUid: 'u1', actorUid: 'it1' }), (error) => error.code === 'conflict');
  await assert.rejects(assignSeat({ tx, licenseId: 'l1', employeeUid: 'u2', actorUid: 'it1' }), (error) => error.code === 'capacity_reached');
  await revokeSeat({ tx, licenseId: 'l1', employeeUid: 'u1' });
  assert.equal(tx.value.usedSeats, 0);
});
