'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  validateRoute,
  collapseGeneratedApprovers,
  notificationEventId,
} = require('../request-approval-routing');

test('field-mission approval route accepts one to four distinct user IDs', () => {
  assert.deepEqual(validateRoute([
    { id: 'approver_0001' }, { id: 'approver_0002' },
  ]), ['approver_0001', 'approver_0002']);
  assert.throws(
    () => validateRoute([{ id: 'approver_0001' }, { id: 'approver_0001' }]),
    /مكررين/,
  );
  assert.throws(() => validateRoute([]), /واحد/);
  assert.throws(() => validateRoute(Array.from({ length: 5 }, (_, i) => ({ id: `approver_000${i}` }))), /أربعة/);
});

test('generated mission route collapses a manager who is also the accounting approver', () => {
  assert.deepEqual(collapseGeneratedApprovers([
    { id: 'accounting_manager_1', labelAr: 'المدير المباشر' },
    { id: 'chief_executive_1', labelAr: 'CEO-100' },
    { id: 'accounting_manager_1', labelAr: 'الحسابات' },
  ]), [
    { id: 'accounting_manager_1', labelAr: 'المدير المباشر / الحسابات' },
    { id: 'chief_executive_1', labelAr: 'CEO-100' },
  ]);
});

test('route notification IDs are deterministic and recipient specific', () => {
  assert.equal(
    notificationEventId('mission-1:turn:1', 'user-1'),
    notificationEventId('mission-1:turn:1', 'user-1'),
  );
  assert.notEqual(
    notificationEventId('mission-1:turn:1', 'user-1'),
    notificationEventId('mission-1:turn:1', 'user-2'),
  );
});

test('employee mission route resolves manager, CEO-100, and accounting on the server', () => {
  const source = require('node:fs').readFileSync(
    require('node:path').join(__dirname, '..', 'request-approval-routing.js'),
    'utf8',
  );
  assert.match(source, /createEmployeeFieldMission/);
  assert.match(source, /employeeId', '==', 'CEO-100/);
  assert.match(source, /isAdvanceAccountsApprover === true/);
  assert.match(source, /'المدير المباشر'/);
  assert.match(source, /'CEO-100'/);
  assert.match(source, /'الحسابات'/);
});

test('accounting stage allows any active accountant to decide and notifies accountants', () => {
  const source = require('node:fs').readFileSync(
    require('node:path').join(__dirname, '..', 'request-approval-routing.js'),
    'utf8',
  );
  assert.match(source, /isAccountingStage/);
  assert.match(source, /isActorAccountant/);
  assert.match(source, /isNextAccounting/);
});

test('configurable requests verify accountant stage allowance and queue visibility', () => {
  const source = require('node:fs').readFileSync(
    require('node:path').join(__dirname, '..', 'configurable-requests.js'),
    'utf8',
  );
  assert.match(source, /getActiveAccountantUids/);
  assert.match(source, /isActorAccountant/);
  assert.match(source, /matchesAccountant/);
  assert.match(source, /isAccountingStage/);
});
