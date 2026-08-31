import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'developer entitlement cannot change attendance security safeguards',
    () {
      final securitySource = File(
        'lib/services/attendance_security_service.dart',
      ).readAsStringSync();
      final attendanceSource = File(
        'lib/services/attendance_service.dart',
      ).readAsStringSync();

      expect(
        securitySource,
        contains('_assertAndroidDeveloperOptionsDisabled'),
      );
      expect(securitySource, contains("'developerOptionsEnabled'"));
      expect(securitySource, contains("'adbEnabled'"));
      expect(securitySource, isNot(contains('DeveloperToolsEntitlement')));
      expect(securitySource, isNot(contains('developer_tools_v2')));
      expect(attendanceSource, contains('validateCheckIn'));
      expect(attendanceSource, contains('registeredAttendanceDeviceId'));
      expect(attendanceSource, isNot(contains('DeveloperToolsEntitlement')));
      expect(attendanceSource, isNot(contains('developer_tools_v2')));
    },
  );
}
