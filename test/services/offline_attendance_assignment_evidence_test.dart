import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/offline_attendance_queue_service.dart';

void main() {
  test('assignment evidence survives offline queue serialization', () {
    final action = OfflineAttendanceAction(
      id: 'op',
      type: OfflineAttendanceActionType.checkIn,
      attendanceId: 'u_2026-08-24',
      userId: 'u',
      employeeId: 'E-1',
      employeeName: 'موظف',
      locationId: 'l1',
      locationName: 'المقر',
      assignmentId: 'u_l1',
      assignmentVersion: 4,
      date: '2026-08-24',
      eventTime: DateTime.utc(2026, 8, 24, 7),
      latitude: 30,
      longitude: 31,
      distanceMeters: 4,
      allowedRadius: 80,
      accuracyMeters: 5,
      deviceId: 'device',
      deviceLabel: 'phone',
      biometricVerified: true,
      isLate: false,
      lateMinutes: 0,
      salaryDeductionFraction: 0,
      salaryDeductionAmount: 0,
      salaryCurrency: 'EGP',
      salaryDeductionCode: 'none',
      salaryDeductionLabel: 'لا يوجد خصم',
      salaryDeductionApprovalStatus: 'none',
      status: 'present',
    );

    final restored = OfflineAttendanceAction.fromJson(action.toJson());

    expect(restored.assignmentId, 'u_l1');
    expect(restored.assignmentVersion, 4);
    expect(
      restored.toCheckInFirestore()['attendanceLocationAssignmentId'],
      'u_l1',
    );
  });
}
