'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ticketNotification,
  requestStageNotification,
  requestNotificationOutbox,
} = require('../company-os/notifications');

test('ticket notifications are deduplicated and use canonical private-safe Arabic destinations', () => {
  const input = { operationId: 'operation-ticket-1', ticketId: 'ticket-1', recipientUid: 'employee-1', status: 'resolved' };
  const first = ticketNotification(input);
  const replay = ticketNotification({ ...input, privateNotes: ['secret'] });
  assert.equal(replay.id, first.id);
  assert.equal(first.data.route, '/company-os?ticket=ticket-1');
  assert.match(first.body, /تم حل/);
  assert.equal(JSON.stringify(first).includes('secret'), false);
});

test('request stage notifications are deduplicated and open canonical details', () => {
  const input = {
    operationId: 'approve-manager-1',
    requestId: 'request-1',
    recipientUid: 'finance-1',
    stage: 'finance',
    status: 'pending',
  };
  const first = requestStageNotification(input);
  const replay = requestStageNotification(input);
  assert.equal(replay.id, first.id);
  assert.equal(first.data.route, '/requests/operational/request-1');
  assert.equal(first.data.administrativeRequestId, 'request-1');
  assert.match(first.body, /المالية/);
});

test('final request outbox routes employee to the canonical request details', () => {
  const outbox = requestNotificationOutbox({
    operationId: 'close-request-1',
    requestId: 'request-1',
    requesterUid: 'employee-1',
    stage: { assigneeUid: 'employee-1' },
    status: 'closed',
  });
  assert.equal(outbox.route, '/employee/requests/operational/request-1');
});
