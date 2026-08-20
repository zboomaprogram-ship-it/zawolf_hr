import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_checkin/attendance_checkin.dart';

void main() {
  test('keeps the canonical action identity across retries', () {
    final action = CheckInAction(
      actionId: 'employee-1_2026-08-20',
      employeeScopeId: 'employee-1',
      dateKey: '2026-08-20',
      capturedAt: DateTime.utc(2026, 8, 20, 7),
      payload: const {'attendanceId': 'employee-1_2026-08-20'},
    );

    expect(
      action.copyWith(payload: const {'retry': true}).actionId,
      action.actionId,
    );
  });

  test('receipt expresses new and idempotent saved check-ins', () {
    const recorded = CheckInReceipt(
      attendanceId: 'employee-1_2026-08-20',
      status: CheckInReceiptStatus.recorded,
    );
    const duplicate = CheckInReceipt(
      attendanceId: 'employee-1_2026-08-20',
      status: CheckInReceiptStatus.alreadyRecorded,
    );

    expect(recorded.status, CheckInReceiptStatus.recorded);
    expect(duplicate.status, CheckInReceiptStatus.alreadyRecorded);
  });
}
