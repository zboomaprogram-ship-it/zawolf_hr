import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/services/offline_attendance_queue_service.dart',
  ).readAsStringSync();

  test('queued checkout uses the server gateway receipt', () {
    expect(
      source,
      contains('await _gateway.submitWithReceipt(action.toJson())'),
    );
    expect(source, contains("result['status'] == 'checkout_disabled'"));
  });

  test(
    'disabled queued checkout is terminal and has no Firestore fallback',
    () {
      expect(source, contains('_OfflineSyncResult.checkoutDisabled'));
      expect(
        source,
        contains('if (result == _OfflineSyncResult.checkoutDisabled)'),
      );
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains("collection('attendance')")));
    },
  );
}
