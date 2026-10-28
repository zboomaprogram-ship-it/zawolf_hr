import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/leave_type_policy.dart';
import 'package:zawolf_hr/models/attendance_model.dart';
import 'package:zawolf_hr/services/attendance_period_summary_service.dart';

void main() {
  group('Remote Work Legacy Compatibility & Aliases', () {
    test('LeaveTypePolicy.isRemote identifies all canonical and legacy aliases', () {
      expect(LeaveTypePolicy.isRemote('remote'), isTrue);
      expect(LeaveTypePolicy.isRemote('wfh'), isTrue);
      expect(LeaveTypePolicy.isRemote('work_from_home'), isTrue);
      expect(LeaveTypePolicy.isRemote('عمل عن بعد'), isTrue);
      expect(LeaveTypePolicy.isRemote('يوم عمل عن بعد'), isTrue);

      expect(LeaveTypePolicy.isRemote('annual'), isFalse);
      expect(LeaveTypePolicy.isRemote('sick'), isFalse);
      expect(LeaveTypePolicy.isRemote('casual'), isFalse);
      expect(LeaveTypePolicy.isRemote('unpaid'), isFalse);
    });

    test('LeaveTypePolicy.normalize maps remote aliases to remote', () {
      expect(LeaveTypePolicy.normalize('remote'), equals('remote'));
      expect(LeaveTypePolicy.normalize('عمل عن بعد'), equals('remote'));
      expect(LeaveTypePolicy.normalize('wfh'), equals('remote'));
      expect(LeaveTypePolicy.normalize('work_from_home'), equals('remote'));
    });

    test('AttendancePeriodDay marks remote attendance as present and not absent', () {
      final now = DateTime(2026, 11, 2, 9, 0);
      final att = AttendanceModel(
        attendanceId: 'u1_2026-11-02',
        userId: 'u1',
        employeeId: 'EMP001',
        employeeName: 'Ahmed',
        locationId: 'loc_remote',
        locationName: 'عمل عن بعد',
        date: '2026-11-02',
        checkInTime: now,
        checkInLocation: const GeoPoint(0, 0),
        isLate: false,
        lateMinutes: 0,
        status: 'present',
      );

      final day = AttendancePeriodDay(
        date: now,
        dateKey: '2026-11-02',
        attendance: att,
        isExpectedWorkDay: true,
        isApprovedLeave: false,
      );

      expect(day.isPresent, isTrue);
      expect(day.isAbsent, isFalse);
    });
  });
}
