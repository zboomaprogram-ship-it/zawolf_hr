import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final automatic =
      File('lib/services/automatic_attendance_service.dart').readAsStringSync();
  final profile =
      File('lib/screens/employee/profile_settings.dart').readAsStringSync();

  test(
    'automatic attendance is explicit opt-in and requires always location',
    () {
      expect(automatic, contains('automatic_attendance_enabled_'));
      expect(automatic, contains('LocationPermission.always'));
      expect(automatic, contains('requestIosAlwaysPermission'));
      expect(automatic, contains('prepareAutomaticAttendance(user)'));
    },
  );

  test('permission denial leaves employees with a clear manual path', () {
    expect(automatic, contains('فعّل خدمة الموقع'));
    expect(automatic, contains('السماح بالموقع دائماً'));
    expect(profile, contains('الحضور التلقائي'));
    expect(profile, contains('AutomaticAttendanceService.instance'));
  });

  test('automatic configuration is per account and uses the bound device', () {
    expect(automatic, contains('isEnabledFor(user.uid)'));
    expect(automatic, contains('registeredAttendanceDeviceId'));
    expect(automatic, contains("'userId': user.uid"));
  });

  test(
    'iOS geofence events are queued natively before Flutter drains them',
    () {
      final appDelegate =
          File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(appDelegate, isNot(contains('import FirebaseFirestore')));
      expect(appDelegate, contains('enqueuePendingAttendanceSignal(values)'));
      expect(appDelegate, contains('getIosPendingAttendanceSignals'));
      expect(automatic, contains('_flushPendingIosSignals(user.uid)'));
      expect(automatic, contains('ackIosPendingAttendanceSignals'));
    },
  );
}
