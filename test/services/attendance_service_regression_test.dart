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
      final source =
          File('lib/services/attendance_service.dart').readAsStringSync();

      expect(source, contains("collection('attendanceDevices')"));
      expect(source, contains("registeredAttendanceDeviceId"));
      expect(source, contains("AttendanceSecurityService.deviceDocumentId"));
    },
  );

  test(
    'web location picker keeps coordinates when Google Maps is unavailable',
    () {
      final source =
          File('lib/screens/hr/location_mgmt.dart').readAsStringSync();

      expect(source, contains('GoogleMapsLoader.ensureLoaded()'));
      expect(source, contains('onKeepCoordinates'));
      expect(source, contains('Navigator.pop(context, _selectedPosition)'));
    },
  );

  test(
    'attendance identity continues to use a Cairo-day compatible date key',
    () {
      final source =
          File('lib/services/attendance_service.dart').readAsStringSync();

      expect(source, contains("DateFormat('yyyy-MM-dd')"));
      expect(source, contains("'\${employee.uid}_\${day.dateKey}'"));
    },
  );

  test(
    'an active employee can probe an empty daily attendance slot before check-in',
    () {
      final rules = File('firestore.rules').readAsStringSync();
      final attendanceRules = rules.substring(
        rules.indexOf('match /attendance/{attendanceId}'),
        rules.indexOf('match /attendanceCorrectionRequests/{requestId}'),
      );

      // A missing document contains no employee data. Allowing its get does
      // not disclose a record, but is required before the client can decide
      // whether to create today's attendance through the gateway.
      expect(
        attendanceRules,
        contains(
          '!exists(\n'
          '          /databases/\$(database)/documents/attendance/\$(attendanceId)\n'
          '        )\n'
          '        || isOwner(resource.data.userId)',
        ),
      );
    },
  );

  test(
    'security plug-in outages do not lock out a valid attendance account',
    () {
      final source =
          File(
            'lib/services/attendance_security_service.dart',
          ).readAsStringSync();

      expect(source, contains('Confirmed jailbreak/emulator/Frida'));
      expect(source, contains("id: '\$platform-install-\$installId'"));
      final trustCheck = source.substring(
        source.indexOf('Future<void> _assertTrustedDevice()'),
        source.indexOf(
          'Future<({String id, String label, String? legacyId})> _readDevice()',
        ),
      );
      expect(trustCheck, isNot(contains('تعذر التحقق من أمان الجهاز.')));
    },
  );
}
