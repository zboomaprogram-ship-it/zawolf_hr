'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  validateRoute,
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
