import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/offline_attendance_queue_service.dart';

void main() {
  test('early-leave permission identity survives offline checkout replay', () {
    final action = OfflineAttendanceAction(
      id: 'stable-event-id',
      type: OfflineAttendanceActionType.checkOut,
      attendanceId: 'u_2026-09-16',
      userId: 'u',
      employeeId: 'E-1',
      employeeName: 'موظف',
      locationId: 'l1',
      locationName: 'المقر',
      date: '2026-09-16',
      eventTime: DateTime.utc(2026, 9, 16, 13),
      latitude: 30,
      longitude: 31,
      distanceMeters: 4,
      allowedRadius: 80,
      accuracyMeters: 5,
      deviceId: 'device',
      deviceLabel: 'phone',
      biometricVerified: true,
      totalWorkHours: 6,
      isLate: false,
      lateMinutes: 0,
      salaryDeductionFraction: 0,
      salaryDeductionAmount: 0,
      salaryCurrency: 'EGP',
      salaryDeductionCode: 'none',
      salaryDeductionLabel: 'لا يوجد خصم',
      salaryDeductionApprovalStatus: 'none',
      status: 'present',
      earlyLeavePermissionId: 'permission-1',
    );

    final restored = OfflineAttendanceAction.fromJson(action.toJson());

    expect(restored.id, 'stable-event-id');
    expect(restored.earlyLeavePermissionId, 'permission-1');
    expect(
      restored.eventTime.millisecondsSinceEpoch,
      action.eventTime.millisecondsSinceEpoch,
    );
  });
}
