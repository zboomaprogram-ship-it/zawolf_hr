import 'package:flutter/material.dart';

import '../../../../core/errors/user_safe_failure_message.dart';
import '../../../../theme/theme.dart';
import '../../domain/entities/check_in_presentation_state.dart';

class CheckInStatusFeedback extends StatelessWidget {
  const CheckInStatusFeedback({
    required this.state,
    required this.failureMessage,
    this.onRetry,
    super.key,
  });

  final CheckInPresentationState state;
  final UserSafeFailureMessage? failureMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final resolvedFailureMessage =
        failureMessage ??
        (state.failure == null
            ? null
            : UserSafeFailureMessage.fromFailure(state.failure!));
    final (icon, color, text) = switch (state.status) {
      CheckInViewStatus.saved => (
        Icons.check_circle_outline,
        ZaWolfColors.success,
        state.receipt?.status.name == 'alreadyRecorded'
            ? 'تم تسجيل حضورك مسبقاً لهذا اليوم.'
            : 'تم حفظ تسجيل الحضور بنجاح.',
      ),
      CheckInViewStatus.pendingSync => (
        Icons.sync,
        ZaWolfColors.warning,
        'تم حفظ طلب الحضور وبانتظار المزامنة عند توفر الإنترنت.',
      ),
      CheckInViewStatus.requiresStatusCheck => (
        Icons.manage_search,
        ZaWolfColors.warning,
        'تعذر تأكيد النتيجة. تحقق من حالة الطلب قبل إعادة الإرسال.',
      ),
      CheckInViewStatus.failed => (
        Icons.info_outline,
        ZaWolfColors.error,
        resolvedFailureMessage?.text ??
            'تعذر إتمام تسجيل الحضور. تواصل مع المسؤول.',
      ),
      CheckInViewStatus.submitting => (
        Icons.hourglass_top,
        ZaWolfColors.primaryCyan,
        'جارٍ حفظ تسجيل الحضور…',
      ),
      CheckInViewStatus.idle => (Icons.info_outline, Colors.transparent, ''),
    };
    if (state.status == CheckInViewStatus.idle) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(text)),
              ],
            ),
            if (onRetry != null &&
                (state.status == CheckInViewStatus.pendingSync ||
                    state.status == CheckInViewStatus.requiresStatusCheck))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(
                    state.status == CheckInViewStatus.requiresStatusCheck
                        ? 'تحقق من الحالة'
                        : 'إعادة المحاولة',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
