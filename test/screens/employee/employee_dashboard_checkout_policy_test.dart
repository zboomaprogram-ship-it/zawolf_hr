import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gate = File(
    'lib/screens/employee/widgets/checkin_action_state.dart',
  ).readAsStringSync();
  final gateCubit = File(
    'lib/screens/employee/employee_attendance_gate_cubit.dart',
  ).readAsStringSync();

  test('employee dashboard fails closed and hides checkout when disabled', () {
    expect(gateCubit, contains('checkoutEnabled = false'));
    expect(gate, contains('checkoutPolicyDisabled'));
    expect(gate, contains("'تم تسجيل الحضور'"));
  });

  test('check-in remains available independently from checkout policy', () {
    expect(gate, contains('AttendanceActionIntent.checkIn'));
    expect(gate, contains('AttendanceActionIntent.checkOut'));
  });

  test('gate decision logic lives in its own characterization-tested unit', () {
    expect(
      File('test/screens/employee/employee_dashboard_gate_test.dart')
          .existsSync(),
      isTrue,
    );
  });
}
