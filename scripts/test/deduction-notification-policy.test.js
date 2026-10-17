'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { shouldCreateNotification } = require('../deduction-notification-policy');

test('pending and security-review deduction notifications stay silent', () => {
  assert.equal(shouldCreateNotification('salary_deduction_pending'), false);
  assert.equal(shouldCreateNotification('early_leave_deduction_review'), false);
  assert.equal(shouldCreateNotification('attendance_security_review'), false);
  assert.equal(shouldCreateNotification('attendance_security_reviewed'), false);
});

test('only final approved deduction notifications are delivered', () => {
  assert.equal(shouldCreateNotification('salary_deduction_reversed'), false);
  assert.equal(shouldCreateNotification('early_leave_deduction_rejected'), false);
  assert.equal(shouldCreateNotification('salary_deduction_approved'), true);
  assert.equal(shouldCreateNotification('salary_deduction_reviewed'), false);
  assert.equal(shouldCreateNotification('early_leave_deduction_approved'), true);
  assert.equal(shouldCreateNotification('permission_pending_manager'), true);
});

test('released app legacy deduction decisions deliver only HR approvals', () => {
  assert.equal(shouldCreateNotification('salary_deduction_reviewed', {
    title: 'تم اعتماد الخصم',
  }), true);
  assert.equal(shouldCreateNotification('salary_deduction_reviewed', {
    title: 'تم إلغاء الخصم',
  }), false);
});
