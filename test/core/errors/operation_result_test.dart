import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';

void main() {
  test('success exposes its confirmed value without a failure', () {
    const result = OperationResult.success('saved');

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, 'saved');
    expect(result.failureOrNull, isNull);
  });

  test('failure exposes guidance without a success value', () {
    final failure = AppFailure(
      category: FailureCategory.validation,
      recovery: RecoveryGuidance.correctInput,
      outcomeCertainty: OutcomeCertainty.confirmedNotCompleted,
    );
    final result = OperationResult<String>.failure(failure);

    expect(result.isSuccess, isFalse);
    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, failure);
  });
}
