import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';

void main() {
  test('unknown outcome rejects a blind retry recovery', () {
    expect(
      () => AppFailure(
        category: FailureCategory.connectivity,
        recovery: RecoveryGuidance.retrySafely,
        outcomeCertainty: OutcomeCertainty.unknown,
      ),
      throwsArgumentError,
    );
  });

  test('unknown outcome requires checking status before retrying', () {
    final failure = AppFailure(
      category: FailureCategory.connectivity,
      recovery: RecoveryGuidance.checkStatusBeforeRetry,
      outcomeCertainty: OutcomeCertainty.unknown,
    );

    expect(failure.canRetrySafely, isFalse);
    expect(failure.requiresStatusCheck, isTrue);
  });

  test('duplicate conflict is confirmed and cannot be retried', () {
    final failure = AppFailure(
      category: FailureCategory.conflictDuplicate,
      recovery: RecoveryGuidance.doNotRetry,
      outcomeCertainty: OutcomeCertainty.confirmedNotCompleted,
    );

    expect(failure.canRetrySafely, isFalse);
    expect(failure.requiresStatusCheck, isFalse);
  });

  test('diagnostic context refuses sensitive keys', () {
    expect(
      () => AppFailure(
        category: FailureCategory.access,
        recovery: RecoveryGuidance.contactResponsibleTeam,
        outcomeCertainty: OutcomeCertainty.confirmedNotCompleted,
        diagnosticContext: const {'token': 'secret-value'},
      ),
      throwsArgumentError,
    );
  });
}
