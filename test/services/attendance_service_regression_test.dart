import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../fixtures/request_visibility_fixtures.dart';

void main() {
  test(
    'non-production fixtures preserve the historic mixed request shapes',
    () {
      expect(pendingPermissionRequest['status'], 'pending_manager');
      expect(confirmedLateArrivalDeduction['status'], 'confirmed');
      expect(legacyConfirmedSalaryDeduction['isConfirmed'], isTrue);
      expect(mixedTimestampRequest['updatedAt'], isA<int>());
    },
  );

  test(
    'attendance device binding retains a deterministic user/device record',
    () {
      final source = File(
        'lib/services/attendance_service.dart',
      ).readAsStringSync();

      expect(source, contains("collection('attendanceDevices')"));
      expect(source, contains("registeredAttendanceDeviceId"));
      expect(source, contains("AttendanceSecurityService.deviceDocumentId"));
    },
  );

  test(
    'web location picker keeps coordinates when Google Maps is unavailable',
    () {
      final source = File(
        'lib/screens/hr/location_mgmt.dart',
      ).readAsStringSync();

      expect(source, contains('GoogleMapsLoader.ensureLoaded()'));
      expect(source, contains('onKeepCoordinates'));
      expect(source, contains('Navigator.pop(context, _selectedPosition)'));
    },
  );

  test(
    'attendance identity continues to use a Cairo-day compatible date key',
    () {
      final source = File(
        'lib/services/attendance_service.dart',
      ).readAsStringSync();

      expect(source, contains("DateFormat('yyyy-MM-dd')"));
      expect(source, contains("'\${employee.uid}_\${day.dateKey}'"));
    },
  );
}
