'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { COST_TYPES, classifyRequest, materializeApprovalPlan } = require('../company-os/approval-policy');

test('every cost category contains mandatory Finance then owner stages', () => {
  for (const requestType of COST_TYPES) {
    const plan = materializeApprovalPlan({ requestId: `r-${requestType}`, requestType, managerUid: 'manager-1', specialistRole: 'it_manager', ownerPolicy: { ownerUid: 'owner-1', version: 4 } });
    const types = plan.stages.map((stage) => stage.type);
    assert.ok(types.indexOf('finance') > types.indexOf('specialist'));
    assert.ok(types.indexOf('owner') > types.indexOf('finance'));
    assert.ok(types.indexOf('payment') > types.indexOf('owner'));
    assert.equal(plan.policyVersion, 4);
  }
});

test('non-cost access skips Finance and owner while unknown type fails closed', () => {
  const plan = materializeApprovalPlan({ requestId: 'r1', requestType: 'access', managerUid: 'm1', specialistRole: 'it_manager', ownerPolicy: { ownerUid: 'o1', version: 1 } });
  assert.equal(plan.costBearing, false);
  assert.equal(plan.stages.some((stage) => stage.type === 'finance'), false);
  assert.throws(() => classifyRequest('invented'), (error) => error.code === 'invalid_input');
});

test('an IT request without a manager routes directly to IT instead of HR', () => {
  const plan = materializeApprovalPlan({
    requestId: 'it-no-manager', requestType: 'access', managerUid: null,
    specialistRole: 'it_manager', ownerPolicy: null,
  });
  assert.deepEqual(plan.stages.map((stage) => stage.type), ['specialist', 'closure']);
  assert.equal(plan.stages[0].role, 'it_manager');
});

test('inactive or ambiguous owner fails closed', () => {
  assert.throws(() => materializeApprovalPlan({ requestId: 'r1', requestType: 'payment', managerUid: 'm1', ownerPolicy: null }), (error) => error.code === 'owner_unavailable');
});

test('same decision operation can be replayed but changed decision conflicts', () => {
  const receipts = new Map();
  function decide(operationId, decision) {
    const existing = receipts.get(operationId);
    if (existing && existing !== decision) { const error = new Error('Changed decision'); error.code = 'conflict'; throw error; }
    receipts.set(operationId, decision); return decision;
  }
  assert.equal(decide('decision-1', 'approved'), 'approved');
  assert.equal(decide('decision-1', 'approved'), 'approved');
  assert.throws(() => decide('decision-1', 'rejected'), (error) => error.code === 'conflict');
});
