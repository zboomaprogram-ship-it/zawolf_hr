import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/permission_service.dart';

void main() {
  final requestDay = DateTime(2026, 9, 15);

  test('late arrival marks submission after scheduled start time', () {
    expect(
      PermissionService.lateArrivalSubmittedAfterStart(
        now: DateTime(2026, 9, 15, 8, 59),
        requestDay: requestDay,
        scheduledStartTime: '09:00',
      ),
      isFalse,
    );
    expect(
      PermissionService.lateArrivalSubmittedAfterStart(
        now: DateTime(2026, 9, 15, 9),
        requestDay: requestDay,
        scheduledStartTime: '09:00',
      ),
      isTrue,
    );
  });

  test('late arrival allows submission after scheduled start before check-in', () {
    expect(
      () => PermissionService.validateLateArrivalEligibility(
        now: DateTime(2026, 9, 15, 9, 30),
        requestDay: requestDay,
        scheduledStartTime: '09:00',
        hasCheckedIn: false,
      ),
      returnsNormally,
    );
  });

  test('late arrival always denies an already checked-in day', () {
    expect(
      () => PermissionService.validateLateArrivalEligibility(
        now: DateTime(2026, 9, 15, 8, 30),
        requestDay: requestDay,
        scheduledStartTime: '09:00',
        hasCheckedIn: true,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('لا يمكن تقديم إذن تأخير حضور بعد تسجيل الحضور الفعلي'),
        ),
      ),
    );
  });
}
