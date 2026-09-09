'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  buildRequestNotification,
  employeeUserIdFromRequest,
  managerUserIds,
  recipientUserIds,
  normalizeRequestNotificationInput,
  notificationDocumentId,
} = require('../request-management-notifications');

test('request notification input requires a target and a useful description', () => {
  assert.equal(normalizeRequestNotificationInput({
    collection: 'leaves', requestId: 'leave-1', target: 'manager',
    operationId: 'operation-1', description: '   ',
  }), null);
  assert.deepEqual(normalizeRequestNotificationInput({
    collection: 'leaves', requestId: 'leave-1', target: 'employee',
    operationId: 'operation-1', description: '  يرجى تعديل التاريخ  ',
  }), {
    collection: 'leaves', requestId: 'leave-1', target: 'employee',
    operationId: 'operation-1', description: 'يرجى تعديل التاريخ',
  });
});

test('recipient resolution keeps request managers first and removes duplicates', () => {
  assert.equal(employeeUserIdFromRequest({ userId: 'employee-1' }), 'employee-1');
  assert.deepEqual(managerUserIds({
    request: { managerIds: ['manager-2', 'manager-1'], managerId: 'manager-2' },
    employee: { managerIds: ['manager-1', 'manager-3'] },
  }), ['manager-2', 'manager-1', 'manager-3']);
});

test('notifications prefer the active approval owner, including CEO-100', () => {
  const input = { target: 'manager' };
  assert.deepEqual(recipientUserIds({
    input,
    request: { currentApproverId: 'ceo-user', ceoId: 'ceo-user', managerId: 'manager-1' },
  }), ['ceo-user', 'manager-1']);
  assert.deepEqual(recipientUserIds({
    input: { target: 'employee' },
    request: { requesterId: 'employee-1' },
  }), ['employee-1']);
});

test('notification IDs are retry-safe per operation and recipient', () => {
  const first = notificationDocumentId({
    operationId: 'operation-1', recipientUserId: 'manager-1',
  });
  assert.equal(first, notificationDocumentId({
    operationId: 'operation-1', recipientUserId: 'manager-1',
  }));
  assert.notEqual(first, notificationDocumentId({
    operationId: 'operation-1', recipientUserId: 'manager-2',
  }));
});

test('manager and employee notifications route to their respective request screens', () => {
  const base = {
    collection: 'leaves', requestId: 'leave-1', description: 'راجع التاريخ',
    operationId: 'operation-1',
  };
  const manager = buildRequestNotification({
    input: { ...base, target: 'manager' },
    recipientUserId: 'manager-1', employeeName: 'موظف تجريبي',
  });
  const employee = buildRequestNotification({
    input: { ...base, target: 'employee' },
    recipientUserId: 'employee-1', employeeName: 'موظف تجريبي',
  });
  assert.equal(
    manager.data.route,
    '/manager/requests?category=leaves&requestId=leave-1',
  );
  assert.match(manager.body, /موظف تجريبي/);
  assert.equal(employee.data.route, '/employee/requests?requestId=leave-1');
  assert.equal(employee.body, 'راجع التاريخ');
});

test('request reminders wake push delivery when the Firestore listener is standby', () => {
  const serverSource = fs.readFileSync(
    path.join(__dirname, '..', 'notification-web.js'),
    'utf8',
  );

  assert.match(
    serverSource,
    /schedulePushDispatch\('request_management_notification', 0\)/,
  );
});

test('chat push routes retain the exact protected channel destination', () => {
  const { safeNotificationRoute } = require('../dispatch-notifications');
  assert.equal(
    safeNotificationRoute('/conversations/channel/company%3Ageneral'),
    '/conversations/channel/company%3Ageneral',
  );
  assert.equal(safeNotificationRoute('/conversations/channel/../../admin'), null);
});
