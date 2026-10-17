'use strict';

const APPROVED_DEDUCTION_TYPES = new Set([
  'salary_deduction_approved',
  'early_leave_deduction_approved',
]);

function shouldCreateNotification(type, notification = {}) {
  const value = String(type || '').trim().toLowerCase();
  if (value === 'attendance_security_review' ||
      value === 'attendance_security_reviewed') {
    return false;
  }
  if (value.includes('deduction')) {
    if (APPROVED_DEDUCTION_TYPES.has(value)) return true;
    // Current released mobile clients use one legacy type for either an
    // approval or rejection. The title is server-visible, so retain only the
    // employee's final approved notification until the next app update.
    if (value === 'salary_deduction_reviewed') {
      const text = `${notification.title || ''} ${notification.body || ''}`;
      return /تم اعتماد|اعتمدت الموارد البشرية|approved/i.test(text);
    }
    return false;
  }
  return true;
}

module.exports = { shouldCreateNotification };
