'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { deriveApprovalActorIds, withApprovalActor } = require('../request-approval-history');

test('derives every historical approver without adding pending route members', () => {
  const ids = deriveApprovalActorIds({
    reviewedBy: 'last-reviewer',
    approvalActorIds: ['first-reviewer'],
    approvalHistory: [
      { action: 'submitted', actorId: 'requester' },
      { action: 'approved', actorId: 'accountant' },
    ],
    approvalRoute: [
      { approverId: 'pending-manager', state: 'pending' },
      { approverId: 'accountant', state: 'approved', decidedBy: 'accountant' },
    ],
  });
  assert.deepEqual(new Set(ids), new Set(['first-reviewer', 'last-reviewer', 'accountant']));
  assert.equal(ids.includes('pending-manager'), false);
});

test('withApprovalActor is stable and de-duplicates retries', () => {
  const once = withApprovalActor({ approvalActorIds: ['accountant'] }, 'accountant');
  assert.deepEqual(once, ['accountant']);
});
