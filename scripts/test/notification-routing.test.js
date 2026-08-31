'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  classifyRecipientRoute,
  normalizeNotificationResource,
} = require('../dispatch-notifications');
const {
  normalizeMarkAllRequest,
  normalizeResolveRequest,
} = require('../notification-operations');

test('approver notification resolves to management context with opaque focus id', () => {
  const resource = normalizeNotificationResource({
    type: 'leave_pending_hr',
    data: { requestId: 'leave-7', route: '/employee/requests' },
  });

  assert.deepEqual(
    classifyRecipientRoute({ role: 'hr_admin', resource }),
    {
      path: '/hr/requests',
      focusId: 'leave-7',
      fallbackPath: '/hr/requests',
    },
  );
});

test('employee decision resolves to own request context, never stored manager route', () => {
  const resource = normalizeNotificationResource({
    type: 'leave_approved',
    data: { requestId: 'leave-7', route: '/manager/requests' },
  });

  assert.deepEqual(
    classifyRecipientRoute({ role: 'employee', resource }),
    {
      path: '/employee/requests',
      focusId: 'leave-7',
      fallbackPath: '/employee/requests',
    },
  );
});

test('Company OS approval keeps its authorized canonical detail route', () => {
  const resource = normalizeNotificationResource({
    type: 'company_os_request_pending_finance',
    data: {
      requestId: 'request-7',
      route: '/requests/operational/request-7',
    },
  });

  assert.deepEqual(
    classifyRecipientRoute({ role: 'finance', resource }),
    {
      path: '/requests/operational/request-7',
      focusId: 'request-7',
      fallbackPath: '/requests/operational/request-7',
    },
  );
});

test('resource normalization rejects external route and limits focus id', () => {
  const resource = normalizeNotificationResource({
    type: 'unknown',
    data: {
      route: 'https://outside.example/steal',
      requestId: 'x'.repeat(500),
    },
  });

  assert.equal(resource.storedRoute, null);
  assert.equal(resource.focusId, null);
});

test('bulk read contract requires idempotency and clamps every bounded page', () => {
  assert.deepEqual(
    normalizeMarkAllRequest({
      operationId: 'read-all:employee-7:2026-08-23',
      pageSize: 5000,
      maxPages: 5000,
    }),
    {
      operationId: 'read-all:employee-7:2026-08-23',
      pageSize: 100,
      maxPages: 10,
    },
  );
  assert.equal(normalizeMarkAllRequest({ operationId: '../unsafe' }), null);
});

test('destination contract accepts opaque notification ids only', () => {
  assert.deepEqual(
    normalizeResolveRequest({ notificationId: 'notification-77' }),
    { notificationId: 'notification-77' },
  );
  assert.equal(normalizeResolveRequest({ notificationId: 'https://outside' }), null);
});
