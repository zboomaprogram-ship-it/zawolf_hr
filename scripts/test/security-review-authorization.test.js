'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  canReviewAttendanceSecurity,
} = require('../phase007-authorization');

test('attendance security review is HR/admin only', () => {
  assert.equal(canReviewAttendanceSecurity({ role: 'hr_admin' }), true);
  assert.equal(canReviewAttendanceSecurity({ role: 'hr_manager' }), true);
  assert.equal(canReviewAttendanceSecurity({ role: 'super_admin' }), true);
  assert.equal(canReviewAttendanceSecurity({ role: 'manager' }), false);
  assert.equal(canReviewAttendanceSecurity({ role: 'team_leader' }), false);
  assert.equal(canReviewAttendanceSecurity({ role: 'employee' }), false);
});
