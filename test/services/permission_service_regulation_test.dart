import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/permission_service.dart';

void main() {
  final requestDay = DateTime(2026, 9, 15);

  test('late arrival closes at the employee scheduled start time', () {
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

  test('late arrival always denies an already checked-in day', () {
    expect(
      () => PermissionService.validateLateArrivalEligibility(
        now: DateTime(2026, 9, 15, 8, 30),
        requestDay: requestDay,
        scheduledStartTime: '09:00',
        hasCheckedIn: true,
      ),
      throwsException,
    );
  });
}
