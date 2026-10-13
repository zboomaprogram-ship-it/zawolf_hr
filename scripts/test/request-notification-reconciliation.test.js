'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  approvalAudience,
  hasExistingActionNotification,
  notificationIdentity,
  notificationFor,
  resolveAudienceUsers,
  watchRequestNotifications,
} = require('../request-notification-reconciliation');

const users = [
  { uid: 'employee-1', employeeId: 'EMP-1', role: 'employee', department: 'Sales', isActive: true },
  { uid: 'manager-1', employeeId: 'MGR-1', role: 'manager', department: 'Sales', isActive: true },
  { uid: 'manager-2', employeeId: 'MGR-2', role: 'manager', department: 'Sales', isActive: true },
  { uid: 'hr-1', employeeId: 'HR-200', role: 'hr', department: 'Human Resources', isActive: true },
  { uid: 'admin-1', employeeId: 'ADM-1', role: 'super_admin', isActive: true },
  { uid: 'inactive-hr', role: 'hr', isActive: false },
  { uid: 'accountant-1', role: 'accountant', department: 'Accounting', isActive: true },
];

test('legacy manager chain targets only its current stage owner', () => {
  const request = {
    userId: 'employee-1', status: 'pending_manager', managerId: 'manager-2',
    managerIds: ['manager-1', 'manager-2'], managerApprovalIndex: 1,
  };
  const audience = approvalAudience(request);
  assert.deepEqual(audience.ids, ['manager-2']);
  assert.deepEqual(resolveAudienceUsers(audience, users, request), ['manager-2']);
});

test('route-specific approver excludes unrelated managers and the requester', () => {
  const request = {
    userId: 'employee-1', status: 'pending_manager', currentApprovalIndex: 0,
    approvalRoute: [{ approverType: 'specific_user', specificUserId: 'manager-1' }],
    managerIds: ['manager-1', 'manager-2'],
  };
  const audience = approvalAudience(request);
  assert.deepEqual(resolveAudienceUsers(audience, users, request), ['manager-1']);
});

test('zero current route index is not replaced by a later legacy manager index', () => {
  const request = {
    userId: 'employee-1', status: 'pending_manager', currentApprovalIndex: 0,
    managerApprovalIndex: 1,
    approvalRoute: [
      { approverId: 'manager-1' },
      { approverId: 'manager-2' },
    ],
  };
  assert.deepEqual(
    resolveAudienceUsers(approvalAudience(request), users, request),
    ['manager-1'],
  );
});

test('HR stage reaches active HR only without super admin spam', () => {
  const request = { userId: 'employee-1', status: 'pending_hr' };
  const recipients = resolveAudienceUsers(approvalAudience(request), users, request);
  assert.deepEqual(recipients.sort(), ['hr-1']);
});

test('role stages resolve the accounting pool without notifying HR or managers', () => {
  const request = {
    userId: 'employee-1', status: 'pending_accounts', currentApprovalIndex: 0,
    approvalRoute: [{ approverType: 'accounting' }],
  };
  assert.deepEqual(
    resolveAudienceUsers(approvalAudience(request), users, request),
    ['accountant-1'],
  );
});

test('terminal request notification goes only to the request owner', () => {
  const request = { userId: 'employee-1', status: 'approved' };
  const audience = approvalAudience(request);
  assert.equal(audience.kind, 'employee');
  assert.deepEqual(resolveAudienceUsers(audience, users, request), ['employee-1']);
  assert.equal(notificationFor({
    collection: 'leaves', requestId: 'leave-1', request,
    recipientId: 'employee-1', audience,
  }).data.route, '/employee/requests?requestId=leave-1');
});

test('notification identity is idempotent per request stage and recipient', () => {
  const base = {
    collection: 'permissions', requestId: 'permission-1', recipientId: 'manager-1',
  };
  const first = notificationIdentity({ ...base, request: { status: 'pending_manager', managerApprovalIndex: 0 } });
  assert.equal(first, notificationIdentity({ ...base, request: { status: 'pending_manager', managerApprovalIndex: 0 } }));
  assert.notEqual(first, notificationIdentity({ ...base, request: { status: 'pending_manager', managerApprovalIndex: 1 } }));
});

test('legacy request notification is detected before server recovery writes a duplicate', async () => {
  const calls = [];
  const db = {
    collection: (name) => {
      calls.push(name);
      return {
        doc: () => ({
          collection: () => ({
            where: (field, operator, value) => ({
              limit: () => ({
                get: async () => ({ empty: field !== 'data.permissionId' || operator !== '==' || value !== 'permission-1' }),
              }),
            }),
          }),
        }),
      };
    },
  };
  assert.equal(await hasExistingActionNotification({
    db, collection: 'permissions', requestId: 'permission-1', recipientId: 'manager-1',
  }), true);
  assert.deepEqual(calls, ['notifications']);
});

test('Hostinger runtime starts the request-stage reconciliation listener', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'notification-web.js'), 'utf8');
  assert.match(source, /watchRequestNotifications\(\{/);
  assert.match(source, /schedulePushDispatch\('request_approval_stage', 0\)/);
});

test('request listener ignores Firestore initial added documents', () => {
  const listeners = [];
  const db = {
    collection: () => ({
      where: () => ({
        limit: () => ({
          onSnapshot: (listener) => {
            listeners.push(listener);
            return () => {};
          },
        }),
      }),
    }),
  };
  const stop = watchRequestNotifications({ db, admin: {} });
  assert.equal(listeners.length > 0, true);
  // The initial snapshot contains existing requests as `added`. It must not
  // schedule recovery notifications after a server restart.
  assert.doesNotThrow(() => listeners[0]({
    docChanges: () => [{ type: 'added', doc: { id: 'historic', data: () => ({}) } }],
  }));
  stop();
});
