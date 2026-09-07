import 'package:flutter/material.dart';

String chatErrorText(String code) {
  if (code.contains('conflict') || code.contains('revision')) return 'تغيرت البيانات على جهاز آخر. حدّث المحادثة وراجع التغيير قبل إعادة المحاولة.';
  if (code.contains('storage') || code.contains('quota')) return 'المساحة المحلية غير كافية. حرّر مساحة ثم أعد المحاولة؛ احتفظ بنص الرسالة.';
  if (code.contains('access') || code.contains('forbidden')) return 'لم يعد لديك إذن لهذه العملية. حدّث المحادثة.';
  if (code.contains('attachment_limit') || code.contains('too_large')) return 'أرفق حتى 10 ملفات، بحجم أقصى 25 MB لكل ملف.';
  if (code.contains('window') || code.contains('expired')) return 'انتهت مهلة التعديل أو الحذف (15 دقيقة).';
  if (code.contains('validation')) return 'راجع البيانات المطلوبة ثم أعد المحاولة.';
  return 'تعذر إكمال العملية. تحقق من الاتصال وأعد المحاولة.';
}

class ChatFeedback extends StatelessWidget {
  const ChatFeedback({super.key, required this.text, this.onRetry, this.icon = Icons.info_outline});
  final String text;
  final VoidCallback? onRetry;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
      Icon(icon, size: 20), const SizedBox(width: 8), Expanded(child: Text(text)),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
    ])),
  );
}
