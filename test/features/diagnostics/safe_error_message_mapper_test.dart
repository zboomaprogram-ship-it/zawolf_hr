import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/safe_operation_error.dart';
import 'package:zawolf_hr/features/diagnostics/presentation/safe_error_message_mapper.dart';

void main() {
  test('safe operation messages are Arabic and provider-neutral', () {
    for (final code in SafeOperationErrorCode.values) {
      final message = safeOperationMessage(SafeOperationError(code: code));
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(message), isTrue);
      expect(message.toLowerCase(), isNot(contains('firebase')));
      expect(message.toLowerCase(), isNot(contains('cloud_firestore')));
      expect(message.toLowerCase(), isNot(contains('permission-denied')));
    }
  });
}
