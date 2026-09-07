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

  test('iOS trust check does not reject a normal device solely for a proxy signal', () {
    final securitySource = File(
      'lib/services/attendance_security_service.dart',
    ).readAsStringSync();

    expect(securitySource, contains('checkForIssues'));
    expect(securitySource, isNot(contains('instance.isNotTrust')));
    expect(securitySource, contains("'jailbreak'"));
    expect(securitySource, contains("'notRealDevice'"));
    expect(securitySource, contains("'fridaFound'"));
  });
}
