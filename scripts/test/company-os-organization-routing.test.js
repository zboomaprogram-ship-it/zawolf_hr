'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { materializeApprovalPlan, refreshFutureRoutingProjection } = require('../company-os/organization-routing');

test('new requests use current manager while materialized plans remain immutable', () => {
  const oldPlan = materializeApprovalPlan({ requesterUid: 'u1', managerUid: 'm1', createdAt: '2026-08-01T00:00:00Z' });
  const projection = refreshFutureRoutingProjection({ employeeUid: 'u1', managerUid: 'm2', departmentId: 'd2' });
  const newPlan = materializeApprovalPlan({ requesterUid: 'u1', managerUid: projection.managerUid, createdAt: '2026-08-24T00:00:00Z' });
  assert.equal(oldPlan.steps[0].assigneeUid, 'm1');
  assert.equal(newPlan.steps[0].assigneeUid, 'm2');
  assert.equal(Object.isFrozen(oldPlan), true);
});
