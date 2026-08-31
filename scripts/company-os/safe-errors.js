'use strict';

const SAFE_CODES = new Set([
  'access_denied', 'invalid_input', 'conflict', 'capacity_reached',
  'temporary_unavailable', 'status_check_required', 'session_expired',
  'rate_limited',
]);
const PRIVATE_KEYS = /^(?:privateNote|privateNotes|password|token|authorization|secret|stack|rawError)$/i;

function safeFailure(error, { writeMayHaveStarted = false } = {}) {
  const incoming = String(error?.safeCode || error?.code || '');
  const code = SAFE_CODES.has(incoming)
    ? incoming
    : writeMayHaveStarted ? 'status_check_required' : 'temporary_unavailable';
  const retryable = ['temporary_unavailable', 'status_check_required'].includes(code);
  const messages = {
    access_denied: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء.',
    invalid_input: 'تحقق من البيانات المدخلة ثم أعد المحاولة.',
    conflict: 'تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.',
    capacity_reached: 'لا توجد سعة متاحة لهذا الإجراء.',
    temporary_unavailable: 'الخدمة غير متاحة مؤقتاً. أعد المحاولة بعد لحظات.',
    status_check_required: 'تعذر تأكيد النتيجة. تحقق من حالة الطلب قبل إعادة الإرسال.',
    session_expired: 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
    rate_limited: 'تم إرسال محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.',
  };
  return { ok: false, safeCode: code, retryable, status: code, message: messages[code] };
}

function validatePageLimit(value = 25) {
  const limit = Number(value);
  if (![10, 25, 50, 100].includes(limit)) {
    const error = new Error('Unsupported page size'); error.code = 'invalid_input'; throw error;
  }
  return limit;
}

function validateOperationEnvelope(value = {}) {
  const operationId = String(value.operationId || '').trim();
  if (!/^[A-Za-z0-9_.:-]{8,128}$/.test(operationId)) {
    const error = new Error('Invalid operation ID'); error.code = 'invalid_input'; throw error;
  }
  return { operationId, expectedVersion: value.expectedVersion == null ? null : Number(value.expectedVersion) };
}

function redactPrivateFields(value) {
  if (Array.isArray(value)) return value.map(redactPrivateFields);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !PRIVATE_KEYS.test(key))
    .map(([key, child]) => [key, redactPrivateFields(child)]));
}

function safeListEnvelope({ items, scope, nextCursor = null, filters = {} }) {
  return { ok: true, items: redactPrivateFields(items), nextCursor, appliedScope: scope, appliedFilters: redactPrivateFields(filters) };
}

module.exports = { SAFE_CODES, safeFailure, validatePageLimit, validateOperationEnvelope, redactPrivateFields, safeListEnvelope };
