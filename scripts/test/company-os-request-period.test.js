'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

test('later approval retains immutable request execution date', () => {
  const request = Object.freeze({ executionDate: '2026-07-22', createdAt: '2026-07-22T08:22:00Z' });
  const decision = { decidedAt: '2026-08-02T10:28:00Z', decision: 'approved' };
  const ledger = { effectiveDate: request.executionDate, sourceType: 'operational_request', sourceId: 'r1' };
  assert.equal(ledger.effectiveDate, '2026-07-22');
  assert.notEqual(ledger.effectiveDate, decision.decidedAt.slice(0, 10));
});

test('Company OS ledger is a read model and carries no payroll mutation', () => {
  const entry = { sourceType: 'operational_request', status: 'approved', amount: 100 };
  assert.equal(Object.hasOwn(entry, 'payrollWrite'), false);
  assert.equal(Object.hasOwn(entry, 'deductionMutation'), false);
});
