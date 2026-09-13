function workspaceSafeError(error, { writeMayHaveStarted = false } = {}) {
  const code = error && error.code;
  const status = error && Number(error.statusCode || error.status);
  const providerMessage = String(
    error?.message || error?.response?.data?.error?.message || '',
  );
  // Google returns a 403 for both authorization and exhausted Drive storage.
  // Detect quota before the generic 403 branch so HR receives an actionable,
  // provider-neutral recovery message rather than a false permission denial.
  if (code === 'drive_storage_quota' ||
      /(?:drive\s+)?storage quota has been exceeded|storage quota.*exceeded|quota.*exceeded/i.test(providerMessage)) {
    return {
      statusCode: 429,
      code: 'drive_storage_quota',
      error: 'مساحة تخزين ملفات الشركة ممتلئة. حرر مساحة أو اضبط ملف تقارير تملكه الشركة ثم أعد المحاولة.',
      retry: 'contact_responsible',
    };
  }
  if (code === 'not_authorized' || code === 'forbidden' || status === 403) {
    return { statusCode: 403, error: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء.', retry: 'contact_responsible' };
  }
  if (code === 'not_found' || status === 404) {
    return { statusCode: 404, error: 'الملف أو المورد المطلوب غير متاح.', retry: 'check_status' };
  }
  if (code === 'validation' || code === 'body_too_large' || status === 400 || status === 422) {
    return { statusCode: 400, error: 'تحقق من البيانات المدخلة ثم أعد المحاولة.', retry: 'correct_input' };
  }
  if (status === 401) {
    return { statusCode: 401, error: 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.', retry: 'sign_in' };
  }
  if (status === 409 || code === 'already_exists') {
    return { statusCode: 409, error: 'تم التعامل مع العملية بالفعل. راجع الحالة الحالية.', retry: 'check_status' };
  }
  if (status === 429) {
    return { statusCode: 429, error: 'تعذر تنفيذ العملية حالياً. أعد المحاولة لاحقاً.', retry: 'retry' };
  }
  return writeMayHaveStarted
    ? { statusCode: 503, error: 'تعذر تأكيد نتيجة العملية. راجع الحالة قبل إعادة الإرسال.', retry: 'check_status' }
    : { statusCode: 503, error: 'الخدمة غير متاحة مؤقتاً. أعد المحاولة بعد لحظات.', retry: 'retry' };
}

module.exports = { workspaceSafeError };
