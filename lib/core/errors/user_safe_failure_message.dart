import 'app_failure.dart';
import 'failure_category.dart';

/// Arabic presentation content derived only from a structured [AppFailure].
final class UserSafeFailureMessage {
  const UserSafeFailureMessage({
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  final String title;
  final String body;
  final String actionLabel;

  String get text => '$title\n$body';

  factory UserSafeFailureMessage.fromFailure(AppFailure failure) {
    if (failure.outcomeCertainty == OutcomeCertainty.unknown) {
      return const UserSafeFailureMessage(
        title: 'تعذر تأكيد نتيجة العملية',
        body: 'راجع حالة الطلب قبل إعادة الإرسال لتجنب التكرار.',
        actionLabel: 'مراجعة الحالة',
      );
    }

    return switch (failure.category) {
      FailureCategory.access => const UserSafeFailureMessage(
        title: 'لا تتوفر لك صلاحية تنفيذ هذا الإجراء',
        body: 'تواصل مع المسؤول عن النظام أو الموارد البشرية.',
        actionLabel: 'تواصل مع المسؤول',
      ),
      FailureCategory.authenticationSession => const UserSafeFailureMessage(
        title: 'انتهت جلسة الدخول',
        body: 'سجل الدخول مرة أخرى ثم أكمل العملية.',
        actionLabel: 'تسجيل الدخول',
      ),
      FailureCategory.validation => const UserSafeFailureMessage(
        title: 'تحقق من البيانات المدخلة',
        body: 'أكمل أو صحح البيانات ثم أعد المحاولة.',
        actionLabel: 'تعديل البيانات',
      ),
      FailureCategory.connectivity => const UserSafeFailureMessage(
        title: 'تعذر الاتصال بالخدمة',
        body: 'تحقق من الاتصال بالإنترنت ثم أعد المحاولة.',
        actionLabel: 'إعادة المحاولة',
      ),
      FailureCategory.temporaryService => const UserSafeFailureMessage(
        title: 'الخدمة غير متاحة مؤقتاً',
        body: 'انتظر لحظات ثم أعد المحاولة.',
        actionLabel: 'إعادة المحاولة',
      ),
      FailureCategory.capacityQuota => const UserSafeFailureMessage(
        title: 'تعذر تنفيذ العملية حالياً',
        body: 'انتظر قليلاً ثم أعد المحاولة أو تواصل مع المسؤول.',
        actionLabel: 'تواصل مع المسؤول',
      ),
      FailureCategory.conflictDuplicate => const UserSafeFailureMessage(
        title: 'تم التعامل مع الطلب بالفعل',
        body: 'راجع السجل الحالي بدلاً من إعادة إرسال الطلب.',
        actionLabel: 'عرض السجل',
      ),
      FailureCategory.missingData => const UserSafeFailureMessage(
        title: 'البيانات المطلوبة غير متاحة',
        body: 'تحقق من البيانات أو اختر سجلاً صحيحاً ثم أعد المحاولة.',
        actionLabel: 'تعديل البيانات',
      ),
      FailureCategory.unexpected => const UserSafeFailureMessage(
        title: 'تعذر إتمام العملية',
        body: 'راجع الحالة أو تواصل مع المسؤول قبل إعادة المحاولة.',
        actionLabel: 'مراجعة الحالة',
      ),
    };
  }
}
