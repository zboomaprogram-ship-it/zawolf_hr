import 'package:flutter/material.dart';

String chatErrorText(String code) {
  if (code.contains('session_expired') || code.contains('unauthenticated')) {
    return 'انتهت جلسة الدخول. يرجى تسجيل الدخول مجدداً لمتابعة المحادثة.';
  }
  if (code.contains('conflict') || code.contains('revision')) {
    return 'تغيرت البيانات على جهاز آخر. حدّث المحادثة وراجع التغيير قبل إعادة المحاولة.';
  }
  if (code.contains('attachment_limit') ||
      code.contains('too_large') ||
      code.contains('http_413') ||
      code.contains('payload_too_large')) {
    return 'أرفق حتى 10 ملفات، بحجم أقصى 25 MB لكل ملف.';
  }
  if (code.contains('unsupported_media') || code.contains('http_415')) {
    return 'صيغة الملف المرفق غير مدعومة في المحادثة.';
  }
  if (code.contains('invalid_voice')) {
    return 'صيغة التسجيل الصوتي غير مدعومة. سجّل رسالة جديدة ثم أعد الإرسال.';
  }
  if (code.contains('window_expired') || code.contains('window')) {
    return 'انتهت مهلة التعديل أو الحذف (15 دقيقة).';
  }
  if (code.contains('access') ||
      code.contains('forbidden') ||
      code.contains('http_403')) {
    return 'لم يعد لديك إذن لهذه العملية. حدّث المحادثة.';
  }
  if (code.contains('not_found') || code.contains('http_404')) {
    return 'المحادثة أو الرسالة المطلوبة لم تعد موجودة.';
  }
  if (code.contains('rate_limit') ||
      code.contains('too_many') ||
      code.contains('http_429')) {
    return 'تم إرسال عدد كبير من الرسائل بسرعة. انتظر لحظات ثم أعد المحاولة.';
  }
  if (code.contains('server_error') ||
      code.contains('http_500') ||
      code.contains('http_502') ||
      code.contains('http_503')) {
    return 'خادم المحادثات يواجه ضغطاً مؤقتاً. جاري إعادة المحاولة تلقائياً.';
  }
  if (code.contains('storage') || code.contains('quota')) {
    return 'المساحة المحلية غير كافية. حرّر مساحة ثم أعد المحاولة؛ احتفظ بنص الرسالة.';
  }
  if (code.contains('validation')) {
    return 'راجع البيانات المطلوبة ثم أعد المحاولة.';
  }
  if (code.contains('connection_interrupted') ||
      code.contains('network') ||
      code.contains('timeout')) {
    return 'تعذر الاتصال بالخادم. تحقق من الإنترنت؛ وسيتم الإرسال فور عودة الاتصال.';
  }
  return 'تعذر إكمال العملية. تحقق من الاتصال وأعد المحاولة.';
}

class ChatFeedback extends StatelessWidget {
  const ChatFeedback({
    super.key,
    required this.text,
    this.onRetry,
    this.icon = Icons.info_outline,
  });
  final String text;
  final VoidCallback? onRetry;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );
}
