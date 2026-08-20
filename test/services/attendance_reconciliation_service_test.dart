import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/services/attendance_reconciliation_service.dart',
  ).readAsStringSync();

  test(
    'approved early leave does not reconcile checkout consequences when off',
    () {
      expect(
        source,
        contains("attendanceData['checkoutPolicyEnabled'] != false"),
      );
      expect(source, contains("permission.permissionType == 'early_leave'"));
    },
  );
}
