import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_model.dart';
import 'package:zawolf_hr/models/attendance_policy.dart';
import 'package:zawolf_hr/models/leave_model.dart';
import 'package:zawolf_hr/services/sheets_export_service.dart';

void main() {
  group('SheetsExportService CSV export', () {
    test('escapes commas and quotes in attendance rows', () async {
      final service = SheetsExportService();
      final csv = await service.exportAttendanceToSheet('attendance', [
        AttendanceModel(
          attendanceId: 'att-1',
          userId: 'user-1',
          employeeId: 'ZW-1',
          employeeName: 'Sara, "Ops"',
          locationId: 'loc-1',
          locationName: 'HQ',
          managerId: 'manager-1',
          date: '2026-07-02',
          checkInTime: DateTime(2026, 7, 2, 9),
          checkInLocation: const GeoPoint(30.0, 31.0),
          isWithinGeofence: true,
          isLate: false,
          lateMinutes: 0,
          status: 'present',
        ),
      ]);

      expect(csv, contains('"Sara, ""Ops"""'));
      expect(csv, contains('حاضر'));
    });

    test('includes leave status translations', () async {
      final service = SheetsExportService();
      final csv = await service.exportLeavesToSheet('leaves', [
        LeaveModel(
          leaveId: 'leave-1',
          userId: 'user-1',
          employeeId: 'ZW-1',
          employeeName: 'Sara',
          department: 'Operations',
          locationId: 'loc-1',
          managerId: 'manager-1',
          leaveType: 'annual',
          startDate: DateTime(2026, 7, 2),
          endDate: DateTime(2026, 7, 3),
          numberOfDays: 2,
          status: 'approved',
        ),
      ]);

      expect(csv, contains('إجازة سنوية'));
      expect(csv, contains('مقبول'));
    });
  });

  group('AttendancePolicy', () {
    test('applies Zawolf late salary deduction windows', () {
      AttendanceDeduction at(int hour, int minute) {
        return AttendancePolicy.evaluateLateArrival(
          arrivalTime: DateTime(2026, 7, 4, hour, minute),
        );
      }

      expect(at(9, 0).dayFraction, 0);
      expect(at(9, 15).dayFraction, 0);
      expect(at(9, 16).dayFraction, 0.25);
      expect(at(9, 30).dayFraction, 0.25);
      expect(at(9, 31).dayFraction, 0.5);
      expect(at(10, 0).dayFraction, 0.5);
      expect(at(10, 1).dayFraction, 1);
      expect(at(17, 0).dayFraction, 1);
    });

    test(
      'calculates deduction amount from monthly salary over 26 work days',
      () {
        expect(
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: 26000,
            dayFraction: 0.25,
          ),
          250,
        );
        expect(
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: 26000,
            dayFraction: 0.5,
          ),
          500,
        );
        expect(
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: 26000,
            dayFraction: 1,
          ),
          1000,
        );
      },
    );
  });
}
