import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/attendance_service.dart';

void main() {
  group('AttendanceService checkout allowance characterization', () {
    test('normal scheduled checkout opens at scheduled end time with no permissions', () {
      final baseEnd = DateTime(2026, 9, 16, 17);
      final allowedFrom = resolveCheckoutAllowedFromForPermissions(baseEnd, const []);
      expect(allowedFrom, baseEnd);
    });

    test('approved early leave advances checkout by duration minutes', () {
      final baseEnd = DateTime(2026, 9, 16, 17);
      final allowedFrom = resolveCheckoutAllowedFromForPermissions(baseEnd, [
        {
          'status': 'approved',
          'permissionType': 'early_leave',
          'durationMinutes': 120,
        },
      ]);
      expect(allowedFrom, DateTime(2026, 9, 16, 15));
    });

    test('earliest approved early leave wins deterministically among multiple permissions', () {
      final baseEnd = DateTime(2026, 9, 16, 17);
      final allowedFrom = resolveCheckoutAllowedFromForPermissions(baseEnd, [
        {
          'status': 'approved',
          'permissionType': 'early_leave',
          'durationMinutes': 60,
        },
        {
          'status': 'approved',
          'permissionType': 'early_leave',
          'durationMinutes': 180,
        },
      ]);
      expect(allowedFrom, DateTime(2026, 9, 16, 14));
    });
  });
}
