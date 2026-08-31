'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeOperationsQuery,
  recordInActorScope,
  boundedSearch,
  boundedAudit,
  boundedReport,
  safeCsv,
} = require('../company-os/operations');

function doc(id, data) {
  return { id, exists: true, data: () => data };
}

function fakeDb(fixtures) {
  const limits = [];
  class Query {
    constructor(name, values, cursor = null, max = null) {
      this.name = name; this.values = values; this.cursor = cursor; this.max = max;
    }
    where(field, operator, value) {
      assert.equal(operator, '==');
      return new Query(this.name, this.values.filter((item) => item.data()[field] === value), this.cursor, this.max);
    }
    orderBy() { return this; }
    startAfter(value) { return new Query(this.name, this.values, value.id, this.max); }
    limit(value) { limits.push(value); return new Query(this.name, this.values, this.cursor, value); }
    async get() {
      const start = this.cursor ? this.values.findIndex((item) => item.id === this.cursor) + 1 : 0;
      const values = this.values.slice(start, this.max == null ? undefined : start + this.max);
      return { docs: values, size: values.length };
    }
    doc(id) {
      return { get: async () => this.values.find((value) => value.id === id) || { exists: false } };
    }
  }
  return {
    limits,
    collection(name) { return new Query(name, fixtures[name] || []); },
  };
}

test('operations queries reject unsupported types and oversized pages', () => {
  assert.equal(normalizeOperationsQuery({ type: 'ticket', limit: 100 }).limit, 100);
  assert.throws(() => normalizeOperationsQuery({ type: 'ticket', limit: 500 }), (error) => error.code === 'invalid_input');
  assert.throws(() => normalizeOperationsQuery({ type: 'secret' }), (error) => error.code === 'invalid_input');
});

test('manager, specialist and employee scope fail closed', () => {
  const manager = { uid: 'm1', role: 'manager', teamUserIds: ['u1'], active: true };
  assert.equal(recordInActorScope(manager, { requesterUid: 'u1' }), true);
  assert.equal(recordInActorScope(manager, { requesterUid: 'u2' }), false);
  const it = { uid: 'it1', role: 'it_support', departmentId: 'd1', active: true };
  assert.equal(recordInActorScope(it, { departmentId: 'd2' }), false);
  assert.equal(recordInActorScope({ uid: 'u1', role: 'employee', active: true }, { requesterUid: 'u2' }), false);
});

test('query text is normalized and bounded', () => {
  const input = normalizeOperationsQuery({ type: 'asset', query: ' X '.repeat(100) });
  assert.ok(input.query.length <= 120);
});

test('bounded search applies scope, pagination and private-field exclusion', async () => {
  const db = fakeDb({
    companyOsTickets: [
      doc('t1', { requesterUid: 'u1', subject: 'حاسب', status: 'open', privateNotes: ['secret'], token: 'nope' }),
      doc('t2', { requesterUid: 'u2', subject: 'طابعة', status: 'open' }),
      doc('t3', { requesterUid: 'u1', subject: 'هاتف', status: 'open' }),
    ],
  });
  const actor = { uid: 'u1', role: 'employee', active: true };
  const first = await boundedSearch({ db, actor, input: { type: 'ticket', limit: 10 } });
  assert.deepEqual(first.items.map((item) => item.id), ['t1', 't3']);
  assert.deepEqual(Object.keys(first.items[0]).sort(), ['id', 'route', 'safeSubtitle', 'title', 'type']);
  assert.equal(JSON.stringify(first).includes('secret'), false);
  assert.equal(JSON.stringify(first).includes('nope'), false);
  assert.equal(db.limits.every((value) => value <= 100), true);
});

test('report and CSV export contain only safe projection fields', async () => {
  const db = fakeDb({
    administrativeRequests: [doc('r1', {
      category: 'company_os', requesterUid: 'u1', subject: 'شراء شاشة', status: 'pending', salary: 5000,
    })],
  });
  const actor = { uid: 'a1', role: 'admin', active: true };
  const report = await boundedReport({ db, actor, input: { type: 'request', reportType: 'requests', limit: 10 } });
  const csv = safeCsv(report.items);
  assert.equal(report.reportType, 'requests');
  assert.match(csv, /شراء شاشة/);
  assert.doesNotMatch(csv, /salary|5000/);
});

test('audit explorer is append-only shaped, scoped and redacted', async () => {
  const db = fakeDb({
    companyOsAuditEvents: [
      doc('a1', { operationId: 'a1', actorUid: 'u1', actorRole: 'employee', action: 'create', targetType: 'ticket', targetId: 't1', safeAfter: { status: 'open', token: 'secret' } }),
      doc('a2', { operationId: 'a2', actorUid: 'u2', actorRole: 'employee', action: 'create', targetType: 'ticket', targetId: 't2' }),
    ],
  });
  const page = await boundedAudit({ db, actor: { uid: 'u1', role: 'employee', active: true }, input: { limit: 10 } });
  assert.deepEqual(page.items.map((item) => item.id), ['a1']);
  assert.equal(JSON.stringify(page).includes('secret'), false);
});
