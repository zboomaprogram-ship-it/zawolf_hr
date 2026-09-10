import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dashboard =
      File('lib/screens/employee/employee_dashboard.dart').readAsStringSync();
  final service =
      File('lib/services/attendance_service.dart').readAsStringSync();

  test('attendance confirmation uses the completed action receipt', () {
    final start = dashboard.indexOf(
      'Future<void> _showAttendanceConfirmation(',
    );
    final end = dashboard.indexOf(
      'Future<bool> _submitReliableCheckIn(',
      start,
    );
    final confirmation = dashboard.substring(start, end);

    expect(confirmation, contains('AttendanceActionResult result'));
    expect(
      confirmation,
      contains('result.action == AttendanceActionIntent.checkOut'),
    );
    expect(confirmation, contains('result.confirmedOnline'));
    expect(
      confirmation,
      isNot(contains('loadTodayAttendanceForDisplay')),
      reason: 'a delayed Firestore read may describe the preceding action',
    );
  });

  test('attendance service returns online state and action for both paths', () {
    expect(service, contains('class AttendanceActionResult'));
    expect(service, contains('action: AttendanceActionIntent.checkIn'));
    expect(service, contains('action: AttendanceActionIntent.checkOut'));
    expect(service, contains('confirmedOnline: savedOnline'));
  });
}
