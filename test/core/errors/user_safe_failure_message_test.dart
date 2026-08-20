import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';

void main() {
  test('every failure category gives Arabic guidance without diagnostics', () {
    final cases =
        <
          ({
            FailureCategory category,
            RecoveryGuidance recovery,
            String nextAction,
          })
        >[
          (
            category: FailureCategory.access,
            recovery: RecoveryGuidance.contactResponsibleTeam,
            nextAction: 'المسؤول',
          ),
          (
            category: FailureCategory.authenticationSession,
            recovery: RecoveryGuidance.signInAgain,
            nextAction: 'الدخول',
          ),
          (
            category: FailureCategory.validation,
            recovery: RecoveryGuidance.correctInput,
            nextAction: 'البيانات',
          ),
          (
            category: FailureCategory.connectivity,
            recovery: RecoveryGuidance.retrySafely,
            nextAction: 'الاتصال',
          ),
          (
            category: FailureCategory.temporaryService,
            recovery: RecoveryGuidance.retrySafely,
            nextAction: 'المحاولة',
          ),
          (
            category: FailureCategory.capacityQuota,
            recovery: RecoveryGuidance.contactResponsibleTeam,
            nextAction: 'قليلاً',
          ),
          (
            category: FailureCategory.conflictDuplicate,
            recovery: RecoveryGuidance.doNotRetry,
            nextAction: 'السجل',
          ),
          (
            category: FailureCategory.missingData,
            recovery: RecoveryGuidance.correctInput,
            nextAction: 'البيانات',
          ),
          (
            category: FailureCategory.unexpected,
            recovery: RecoveryGuidance.checkStatusBeforeRetry,
            nextAction: 'حالة',
          ),
        ];

    for (final item in cases) {
      final message = UserSafeFailureMessage.fromFailure(
        AppFailure(
          category: item.category,
          recovery: item.recovery,
          outcomeCertainty: item.category == FailureCategory.unexpected
              ? OutcomeCertainty.unknown
              : OutcomeCertainty.confirmedNotCompleted,
          diagnosticKey: 'support-reference-123',
        ),
      );

      expect(message.title, isNotEmpty);
      expect(message.body, contains(item.nextAction));
      expect(message.text, isNot(contains('support-reference-123')));
    }
  });

  test(
    'unknown outcomes tell the employee to check status before retrying',
    () {
      final message = UserSafeFailureMessage.fromFailure(
        AppFailure(
          category: FailureCategory.temporaryService,
          recovery: RecoveryGuidance.checkStatusBeforeRetry,
          outcomeCertainty: OutcomeCertainty.unknown,
        ),
      );

      expect(message.body, contains('راجع حالة الطلب'));
      expect(message.actionLabel, 'مراجعة الحالة');
    },
  );
}
