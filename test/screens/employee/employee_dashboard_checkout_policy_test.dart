import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/employee/employee_dashboard.dart',
  ).readAsStringSync();

  test('employee dashboard fails closed and hides checkout when disabled', () {
    expect(source, contains('_checkoutEnabled = false'));
    expect(source, contains('checkoutPolicyDisabled'));
    expect(source, contains("'تم تسجيل الحضور'"));
  });

  test('check-in remains available independently from checkout policy', () {
    expect(source, contains('AttendanceActionIntent.checkIn'));
    expect(source, contains('AttendanceActionIntent.checkOut'));
  });
}
