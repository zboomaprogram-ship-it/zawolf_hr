import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/employee/employee_dashboard.dart',
  ).readAsStringSync();

  test(
    'keeps the reliability pilot disabled unless a specific user is chosen',
    () {
      expect(source, contains('ATTENDANCE_CHECKIN_PILOT_USER_ID'));
      expect(source, contains("defaultValue: ''"));
    },
  );

  test('routes only manual check-in through the reliability pilot seam', () {
    expect(
      source,
      contains('expectedAction == AttendanceActionIntent.checkIn'),
    );
    expect(source, contains('reliableCheckInSubmitter:'));
    expect(source, isNot(contains('checkOutPilot')));
  });

  test('uses structured safe feedback for pilot outcomes', () {
    expect(source, contains('CheckInStatusFeedback'));
    expect(source, contains('pilot.cubit.safeFailureMessage()'));
    expect(source, contains('pilotAwaitingConfirmation'));
    expect(source, contains('_retryReliableCheckIn(user.uid)'));
  });

  test('covers denied, temporary, duplicate, and interrupted pilot outcomes', () {
    final mapper = File(
      'lib/features/attendance_checkin/data/attendance_checkin_failure_mapper.dart',
    ).readAsStringSync();
    final cubit = File(
      'lib/features/attendance_checkin/presentation/cubit/checkin_cubit.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/attendance_checkin/data/attendance_checkin_repository_impl.dart',
    ).readAsStringSync();

    // Access/temporary classifications feed the same structured dashboard UI;
    // duplicates are saved and uncertain delivery requires explicit status.
    expect(mapper, contains("'device_mismatch'"));
    expect(mapper, contains("'server_unavailable'"));
    expect(repository, contains('CheckInReceiptStatus.alreadyRecorded'));
    expect(cubit, contains('CheckInViewStatus.requiresStatusCheck'));
  });
}
