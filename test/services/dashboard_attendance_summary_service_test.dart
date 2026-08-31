import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/models/user_model.dart';
import 'package:zawolf_hr/services/dashboard_attendance_summary_service.dart';
import 'package:zawolf_hr/services/attendance_period_summary_service.dart';
import 'package:zawolf_hr/models/leave_model.dart';

void main() {
  test('attended combines on-time and late employees', () {
    final summary = DashboardAttendanceSummary(
      totalEmployees: 10,
      present: 4,
      late: 2,
      permission: 1,
      dayOff: 1,
      notAttended: 2,
      date: DateTime(2026, 7, 29),
      teamScoped: false,
    );

    expect(summary.attended, 6);
    expect(summary.percentOf(summary.attended), 60);
    expect(summary.accounted, 10);
  });

  test('disabled-period attendance is never marked as a missing checkout', () {
    final person = DashboardAttendancePerson(
      employee: _employee(),
      status: 'present',
      checkInTime: DateTime(2026, 8, 20, 9),
      checkoutPolicyEnabled: false,
    );

    expect(person.needsCheckout, isFalse);
    expect(person.checkoutNotRequired, isTrue);
  });

  test(
    'legacy attendance without a policy snapshot retains missing checkout',
    () {
      final person = DashboardAttendancePerson(
        employee: _employee(),
        status: 'late',
        checkInTime: DateTime(2026, 7, 20, 9),
      );

      expect(person.needsCheckout, isTrue);
      expect(person.checkoutNotRequired, isFalse);
    },
  );

  test('approved leave and permission are not counted as unexplained absence', () {
    final employee = _employee();
    final summary = AttendancePeriodSummaryService.buildSummary(
      user: employee,
      start: DateTime(2026, 8, 16),
      end: DateTime(2026, 8, 17),
      now: DateTime(2026, 8, 18, 12),
      attendanceByDate: const {},
      approvedLeaves: [
        LeaveModel(
          leaveId: 'leave-1',
          userId: employee.uid,
          employeeId: employee.employeeId,
          employeeName: employee.displayName,
          department: employee.department,
          locationId: employee.locationId,
          managerId: '',
          leaveType: 'annual',
          startDate: DateTime(2026, 8, 16),
          endDate: DateTime(2026, 8, 16),
          numberOfDays: 1,
          status: 'approved',
        ),
      ],
      approvedPermissionDates: const {'2026-08-17'},
      companyDaysOff: const {},
    );

    expect(summary.absentDays, 0);
    expect(summary.days.firstWhere((day) => day.dateKey == '2026-08-16').isApprovedLeave, isTrue);
    expect(summary.days.firstWhere((day) => day.dateKey == '2026-08-17').isApprovedPermission, isTrue);
  });
}

UserModel _employee() => UserModel(
  uid: 'employee-1',
  email: 'employee@example.com',
  displayName: 'Employee',
  role: EmployeeRole.employee,
  employeeId: 'EMP-001',
  department: 'Operations',
  position: 'Officer',
  locationId: 'hq',
  locationName: 'HQ',
  workSchedule: WorkSchedule(),
  leaveBalance: LeaveBalance(annual: 15, sick: 14, casual: 7, daysOff: 15),
  permissionBalance: PermissionBalance(
    usedThisMonth: 0,
    usedHoursThisMonth: 0,
    lastResetMonth: '2026-08',
  ),
);
