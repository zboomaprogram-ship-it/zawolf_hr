import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';

void main() {
  test('permission denial returns Arabic action without provider details', () {
    final failure = WorkspaceUserFacingError.fromHttpStatus(
      403,
      writeMayHaveStarted: false,
    );
    final message = WorkspaceUserFacingError.messageFor(failure);

    expect(failure.category, FailureCategory.access);
    expect(message.text, contains('صلاحية'));
    expect(message.text.toLowerCase(), isNot(contains('firebase')));
    expect(message.text.toLowerCase(), isNot(contains('google')));
  });

  test('interrupted write requires status check before retry', () {
    final failure = WorkspaceUserFacingError.connectivity(
      writeMayHaveStarted: true,
    );

    expect(failure.requiresStatusCheck, isTrue);
    expect(
      WorkspaceUserFacingError.messageFor(failure).text,
      contains('راجع حالة الطلب'),
    );
  });

  test('a failed read can retry safely', () {
    final failure = WorkspaceUserFacingError.fromHttpStatus(
      503,
      writeMayHaveStarted: false,
    );

    expect(failure.canRetrySafely, isTrue);
  });
}
