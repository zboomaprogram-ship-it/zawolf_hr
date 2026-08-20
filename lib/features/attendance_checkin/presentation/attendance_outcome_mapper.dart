/// UI-safe text for attendance outcomes returned by the company gateway.
///
/// No exception details are accepted here: widgets can render only an outcome
/// code and this fixed Arabic message, never Firebase or transport internals.
final class AttendanceOutcomeMapper {
  const AttendanceOutcomeMapper();

  String messageFor(String? status) => switch (status) {
    'recorded' => 'تم حفظ تسجيل الحضور بنجاح.',
    'already_recorded' => 'تم تسجيل حضورك مسبقاً لهذا اليوم.',
    'checkout_disabled' =>
      'تسجيل الانصراف غير مفعّل حالياً. تم حفظ حضورك ولا يلزم إجراء إضافي.',
    'pending_sync' => 'تم حفظ الطلب وبانتظار المزامنة عند توفر الإنترنت.',
    'unavailable' || 'network' || 'timeout' =>
      'تعذر التأكيد الآن. أعد المحاولة لاحقاً أو تحقق من حالة الطلب.',
    _ => 'تعذر إتمام الطلب الآن. تحقق من حالة الطلب قبل إعادة الإرسال.',
  };
}
