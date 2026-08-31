'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { executeOperation, payloadHash } = require('../company-os/operation-gateway');

function fakeStore() {
  const receipts = new Map();
  const audits = new Map();
  const records = new Map([['ticket-1', { id: 'ticket-1', version: 1, status: 'new' }]]);
  return {
    receipts, audits, records,
    async transact(work) {
      const snapshot = { receipts: new Map(receipts), audits: new Map(audits), records: new Map(records) };
      try { return await work(this); } catch (error) {
        receipts.clear(); for (const [key, value] of snapshot.receipts) receipts.set(key, value);
        audits.clear(); for (const [key, value] of snapshot.audits) audits.set(key, value);
        records.clear(); for (const [key, value] of snapshot.records) records.set(key, value);
        throw error;
      }
    },
  };
}

test('duplicate retry returns one receipt and one atomic audit', async () => {
  const store = fakeStore();
  const input = { store, operationId: 'operation-0001', actor: { uid: 'actor-1', role: 'employee' }, operationType: 'ticket_create', targetId: 'ticket-1', payload: { subject: 'Laptop' }, expectedVersion: 1 };
  const mutate = async (tx) => { tx.records.set('ticket-1', { id: 'ticket-1', version: 2 }); return { resourceId: 'ticket-1', version: 2 }; };
  const first = await executeOperation({ ...input, mutate });
  const replay = await executeOperation({ ...input, mutate: async () => { throw new Error('must not run'); } });
  assert.deepEqual(replay, first);
  assert.equal(store.audits.size, 1);
});

test('same operation ID with changed payload conflicts', async () => {
  const store = fakeStore();
  const base = { store, operationId: 'operation-0002', actor: { uid: 'actor-1', role: 'employee' }, operationType: 'ticket_create', targetId: 'ticket-1', expectedVersion: 1 };
  await executeOperation({ ...base, payload: { subject: 'A' }, mutate: async () => ({ resourceId: 'ticket-1', version: 2 }) });
  await assert.rejects(
    executeOperation({ ...base, payload: { subject: 'B' }, mutate: async () => ({}) }),
    (error) => error.code === 'conflict',
  );
  assert.notEqual(payloadHash({ subject: 'A' }), payloadHash({ subject: 'B' }));
});

test('version conflict or failed audit rolls back mutation and receipt', async () => {
  const store = fakeStore();
  await assert.rejects(executeOperation({
    store,
    operationId: 'operation-0003',
    actor: { uid: 'actor-1', role: 'it_support' },
    operationType: 'ticket_transition',
    targetId: 'ticket-1',
    payload: { status: 'assigned' },
    expectedVersion: 9,
    currentVersion: async () => 1,
    mutate: async () => ({ resourceId: 'ticket-1', version: 2 }),
  }), (error) => error.code === 'conflict');
  assert.equal(store.receipts.size, 0);
  assert.equal(store.audits.size, 0);
});

