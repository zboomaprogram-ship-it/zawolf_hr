import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/services/attendance_service.dart').readAsStringSync();

  test(
    'legacy missed-checkout maintenance cannot block a new attendance event',
    () {
      final start = source.indexOf('Future<void> handleCheckInOrCheckOut(');
      final end = source.indexOf('final todayLookup =', start);
      final actionPath = source.substring(start, end);

      expect(
        actionPath,
        contains(
          'unawaited(_runBackgroundAttendanceMaintenance(employee, todayStr));',
        ),
      );
      expect(
        actionPath,
        isNot(contains('await _flagMissedCheckouts(employee, todayStr)')),
      );
      expect(
        source,
        contains('Future<void> _runBackgroundAttendanceMaintenance('),
      );
      expect(
        source,
        contains(
          "developer.log('Background attendance maintenance deferred: \$error')",
        ),
      );
    },
  );
}
