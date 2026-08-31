import '../domain/entities/safe_operation_error.dart';

/// Arabic copy intentionally contains no provider names or technical codes.
String safeOperationMessage(SafeOperationError error) {
  return switch (error.code) {
    SafeOperationErrorCode.sessionExpired =>
      'انتهت جلسة الدخول. سجّل الدخول مرة أخرى ثم أعد المحاولة.',
    SafeOperationErrorCode.accessDenied =>
      'لا تملك الصلاحية اللازمة لهذه العملية. تواصل مع المسؤول إذا استمرت المشكلة.',
    SafeOperationErrorCode.temporarilyUnavailable =>
      'الخدمة مشغولة مؤقتاً. تم حفظ المحاولة بشكل آمن؛ أعد المحاولة بعد قليل.',
    SafeOperationErrorCode.connectionInterrupted =>
      'انقطع الاتصال. تحقق من الإنترنت ثم أعد المحاولة.',
    SafeOperationErrorCode.alreadySubmitted =>
      'تم تسجيل الطلب مسبقاً. راجع حالة طلباتك قبل الإرسال مرة أخرى.',
    SafeOperationErrorCode.validationFailed =>
      'يرجى مراجعة البيانات المطلوبة ثم إعادة الإرسال.',
    SafeOperationErrorCode.checkRequestStatus =>
      'تعذر تأكيد النتيجة الآن. راجع حالة الطلب قبل إعادة الإرسال.',
    SafeOperationErrorCode.unexpected =>
      'تعذر إكمال العملية حالياً. أعد المحاولة بعد قليل أو تواصل مع المسؤول.',
  };
}
