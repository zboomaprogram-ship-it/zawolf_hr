'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRequest, decideRequest, canActOnStage } = require('../company-os/requests');

function memoryStore() {
  const state = { requests: new Map(), receipts: new Map(), audits: new Map() };
  return {
    state,
    async transact(work) {
      return work({
        getReceipt: async (id) => state.receipts.get(id),
        putReceipt: async (id, value) => state.receipts.set(id, value),
        putAudit: async (id, value) => state.audits.set(id, value),
        getRequest: async (id) => state.requests.get(id),
        createRequest: async (value) => state.requests.set(value.id, value),
        updateRequest: async (id, value) => state.requests.set(id, { ...state.requests.get(id), ...value }),
      });
    },
  };
}

const employee = {
  uid: 'employee-1', active: true, role: 'employee', employeeId: 'EMP-1',
  displayName: 'موظف تجريبي', department: 'IT', managerIds: ['manager-1'],
};

test('request create reuses one canonical request and immutable execution date', async () => {
  const store = memoryStore();
  const input = { requestType: 'payment', businessReason: 'سداد فاتورة', executionDate: '2026-07-22', amount: 150, currency: 'EGP' };
  const args = { store, actor: employee, operationId: 'request-create-1', input, ownerPolicy: { ownerUid: 'owner-1', version: 3 }, now: new Date('2026-08-02T10:00:00Z') };
  const first = await createRequest(args);
  const replay = await createRequest(args);
  assert.deepEqual(replay, first);
  assert.equal(store.state.requests.size, 1);
  const request = store.state.requests.get(first.resourceId);
  assert.equal(request.executionDate.toISOString(), '2026-07-22T00:00:00.000Z');
  assert.deepEqual(request.approvalPlan.stages.map((stage) => stage.type), ['manager', 'finance', 'owner', 'payment', 'closure']);
  assert.equal(request.approvalHistory.length, 1);
});

test('decisions are ordered, versioned and duplicate retries are idempotent', async () => {
  const store = memoryStore();
  const created = await createRequest({
    store, actor: employee, operationId: 'request-create-2',
    input: { requestType: 'access', businessReason: 'صلاحية النظام', executionDate: '2026-08-24' },
    ownerPolicy: { ownerUid: 'owner-1', version: 1 },
  });
  await assert.rejects(
    decideRequest({ store, actor: { uid: 'wrong', active: true, role: 'manager' }, operationId: 'wrong-decision', requestId: created.resourceId, expectedVersion: 1, approved: true, reason: 'موافق' }),
    (error) => error.code === 'access_denied',
  );
  const args = { store, actor: { uid: 'manager-1', active: true, role: 'manager' }, operationId: 'manager-decision', requestId: created.resourceId, expectedVersion: 1, approved: true, reason: 'موافق' };
  const first = await decideRequest(args);
  const replay = await decideRequest(args);
  assert.deepEqual(replay, first);
  const request = store.state.requests.get(created.resourceId);
  assert.equal(request.status, 'pending_specialist');
  assert.equal(request.version, 2);
  assert.equal(request.approvalHistory.length, 2);
});

test('cost request cannot skip Finance or company owner', async () => {
  const store = memoryStore();
  const created = await createRequest({
    store, actor: employee, operationId: 'request-create-3',
    input: { requestType: 'other_expense', businessReason: 'مصروف', executionDate: '2026-08-24', amount: 50 },
    ownerPolicy: { ownerUid: 'owner-1', version: 2 },
  });
  await decideRequest({ store, actor: { uid: 'manager-1', active: true, role: 'manager' }, operationId: 'approve-manager', requestId: created.resourceId, expectedVersion: 1, approved: true, reason: 'موافق' });
  const request = store.state.requests.get(created.resourceId);
  assert.equal(request.approvalPlan.stages[request.currentStageIndex].type, 'finance');
  await assert.rejects(
    decideRequest({ store, actor: { uid: 'owner-1', active: true, role: 'super_admin' }, operationId: 'skip-finance', requestId: created.resourceId, expectedVersion: 2, approved: true, reason: 'موافق' }),
    (error) => error.code === 'access_denied',
  );
});

test('IT requests without a manager go directly to IT and HR cannot close them', async () => {
  const store = memoryStore();
  const noManagerEmployee = { ...employee, managerIds: [] };
  const created = await createRequest({
    store, actor: noManagerEmployee, operationId: 'request-create-no-manager-it',
    input: { requestType: 'access', businessReason: 'صلاحية تطبيق', executionDate: '2026-08-24' },
    ownerPolicy: null,
  });
  const request = store.state.requests.get(created.resourceId);
  assert.equal(request.approvalPlan.stages[0].type, 'specialist');
  assert.equal(request.managerId, null);
  assert.equal(canActOnStage(
    { uid: 'hr-1', active: true, role: 'hr_admin' },
    { type: 'closure', role: 'it_manager', status: 'pending' },
    request,
  ), false);
});
