'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { identities } = require('./fixtures/company-os-fixtures');
const { createEmployeeTicket, listOwnTickets } = require('../company-os/tickets');
const { publicTicket } = require('../company-os/employee-portal');

function store() {
  const tickets = [];
  const receipts = new Map();
  const audits = [];
  return {
    tickets, audits,
    receipt: async (id) => receipts.get(id),
    async createOnce({ operationId, actorUid, ticket, audit }) {
      const result = { ok: true, operationId, status: 'saved', resourceId: ticket.id, version: 1 };
      tickets.push(ticket); audits.push(audit); receipts.set(operationId, result); return result;
    },
    async listByRequester(uid, { limit }) { return { items: tickets.filter((item) => item.requesterUid === uid).slice(0, limit) }; },
  };
}

test('interrupted duplicate submit creates one employee ticket and one audit', async () => {
  const repository = store();
  const input = { store: repository, actor: identities.employee, operationId: 'operation-employee-0001', input: { subject: 'حاسوب العمل', description: 'الجهاز لا يعمل الآن', category: 'laptop' } };
  const first = await createEmployeeTicket(input);
  const replay = await createEmployeeTicket(input);
  assert.deepEqual(replay, first);
  assert.equal(repository.tickets.length, 1);
  assert.equal(repository.audits.length, 1);
  assert.match(first.resourceId, /^ticket_[a-f0-9]{24}$/);
});

test('own list excludes other employees and all private IT fields', async () => {
  const repository = store();
  await createEmployeeTicket({ store: repository, actor: identities.employee, operationId: 'operation-employee-0002', input: { subject: 'البريد', description: 'تعذر تسجيل الدخول', category: 'email' } });
  await createEmployeeTicket({ store: repository, actor: identities.outOfScope, operationId: 'operation-employee-0003', input: { subject: 'طابعة', description: 'الطابعة متوقفة', category: 'printer' } });
  repository.tickets[0].privateNotes = ['secret'];
  const result = await listOwnTickets({ store: repository, actor: identities.employee });
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].privateNotes, undefined);
  assert.equal(publicTicket(repository.tickets[0]).privateNotes, undefined);
  assert.equal(publicTicket(repository.tickets[0]).internalSla, undefined);
});

test('inactive employee cannot create a ticket', async () => {
  await assert.rejects(createEmployeeTicket({ store: store(), actor: identities.inactive, operationId: 'operation-employee-0004', input: { subject: 'حاسوب', description: 'الجهاز متوقف' } }), (error) => error.code === 'access_denied');
});
