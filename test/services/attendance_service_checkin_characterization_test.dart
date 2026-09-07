import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/services/attendance_service.dart').readAsStringSync();

  test('keeps deterministic Cairo daily check-in identity and action type', () {
    expect(source, contains("DateFormat('yyyy-MM-dd').format(now)"));
    expect(source, contains(".doc('\${employee.uid}_\$todayStr')"));
    expect(source, contains("id: '\${logRef.id}_checkIn'"));
  });

  test('keeps checkout logic separate from the check-in pilot seam', () {
    expect(source, contains('// ── CHECK-OUT LOGIC ──'));
    expect(source, contains("id: '\${checkInLog.attendanceId}_checkOut'"));
  });

  test(
    'observes the canonical daily record so a delayed cycle query cannot hide checkout',
    () {
      expect(source, contains('final todayDateKey ='));
      expect(source, contains(".doc('\${userId}_\$todayDateKey')"));
      expect(source, contains('canonicalTodayLog'));
    },
  );

  test(
    'does not make a confirmed attendance action wait for dashboard probes',
    () {
      final dashboard =
          File(
            'lib/screens/employee/employee_dashboard.dart',
          ).readAsStringSync();

      expect(
        dashboard,
        contains('unawaited(_refreshAttendanceAfterAction(employee));'),
      );
      expect(
        dashboard,
        isNot(
          contains('await Future.wait([\n        _checkCurrentGeofence(),'),
        ),
      );
    },
  );

  test(
    'preserves validated location, device, and policy evidence for check-in',
    () {
      expect(source, contains('latitude: geoResult.position.latitude'));
      expect(source, contains('longitude: geoResult.position.longitude'));
      expect(source, contains('deviceId: securityResult.deviceId'));
      expect(
        source,
        contains('biometricVerified: securityResult.biometricVerified'),
      );
      expect(source, contains('lateMinutes: deduction.lateMinutes'));
      expect(
        source,
        contains('salaryDeductionFraction: deduction.dayFraction'),
      );
      expect(source, contains('eventTime: now'));
    },
  );
}
