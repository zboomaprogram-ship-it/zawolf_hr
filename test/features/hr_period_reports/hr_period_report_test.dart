import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/hr_period_reports/domain/hr_period_report.dart';
import 'package:zawolf_hr/features/hr_period_reports/presentation/hr_report_pdf_generator.dart';

void main() {
  test(
    'custom report periods are inclusive and capped at 31 calendar days',
    () {
      final period = HrReportPeriod.custom(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      );
      expect(period.days, 31);
      expect(
        () =>
            HrReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 10, 2)),
        throwsArgumentError,
      );
    },
  );

  test('only approved deductions are marked as discipline affecting', () {
    const employee = HrReportEmployee(
      id: 'u1',
      name: 'موظف',
      code: 'E-1',
      department: 'HR',
    );
    final pending = HrAttendanceRecord(
      employee: employee,
      date: DateTime(2026, 9, 1),
      status: 'late',
      deductionStatus: 'pending_hr',
    );
    final approved = HrAttendanceRecord(
      employee: employee,
      date: DateTime(2026, 9, 2),
      status: 'late',
      deductionStatus: 'approved',
    );
    expect(pending.approvedDeduction, isFalse);
    expect(approved.approvedDeduction, isTrue);
  });

  test(
    'pending salary deductions remain visible without affecting discipline',
    () {
      const employee = HrReportEmployee(
        id: 'u2',
        name: 'موظف',
        code: 'E-2',
        department: 'HR',
      );
      final pending = HrDeductionRecord(
        employee: employee,
        date: DateTime(2026, 9, 1),
        reason: 'غياب',
        status: 'pending_hr',
      );
      final approved = HrDeductionRecord(
        employee: employee,
        date: DateTime(2026, 9, 1),
        reason: 'غياب',
        status: 'approved',
      );
      expect(pending.affectsDiscipline, isFalse);
      expect(approved.affectsDiscipline, isTrue);
    },
  );

  test('deduction amount is derived from salary and day fraction', () {
    const employee = HrReportEmployee(
      id: 'u3',
      name: 'موظف',
      code: 'E-3',
      department: 'HR',
      baseMonthlySalary: 26000,
    );
    final deduction = HrDeductionRecord(
      employee: employee,
      date: DateTime(2026, 9, 9),
      reason: 'تأخير حضور',
      status: 'approved',
      fraction: .25,
    );
    expect(deduction.resolvedAmount(), 250);
  });

  test('trend excludes leave and rest days from scheduled denominator', () {
    const employee = HrReportEmployee(
      id: 'u4',
      name: 'موظف',
      code: 'E-4',
      department: 'HR',
    );
    final report = HrPeriodReport(
      period: HrReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 9, 2)),
      employees: const [employee],
      records: [
        HrAttendanceRecord(
          employee: employee,
          date: DateTime(2026, 9, 1),
          status: 'day_off',
        ),
        HrAttendanceRecord(
          employee: employee,
          date: DateTime(2026, 9, 2),
          status: 'late',
        ),
      ],
    );
    final trend = report.trendForEmployee(null);
    expect(trend.first.scheduled, 0);
    expect(trend.last.scheduled, 1);
    expect(trend.last.attendanceRate, 1);
    expect(trend.last.lateRate, 1);
  });

  test('EmployeeDeductionSummaryItem excludes sign-out deductions and tallies permissions/leaves', () {
    const employee = HrReportEmployee(
      id: 'u5',
      name: 'أحمد علي',
      code: 'E-5',
      department: 'IT',
      baseMonthlySalary: 26000,
    );
    final report = HrPeriodReport(
      period: HrReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 9, 5)),
      employees: const [employee],
      records: [
        HrAttendanceRecord(
          employee: employee,
          date: DateTime(2026, 9, 1),
          status: 'present',
          checkIn: DateTime(2026, 9, 1, 9, 0),
          checkOut: DateTime(2026, 9, 1, 17, 0),
        ),
        HrAttendanceRecord(
          employee: employee,
          date: DateTime(2026, 9, 2),
          status: 'late',
          lateMinutes: 30,
          checkIn: DateTime(2026, 9, 2, 9, 30),
          checkOut: DateTime(2026, 9, 2, 17, 0),
        ),
        HrAttendanceRecord(
          employee: employee,
          date: DateTime(2026, 9, 3),
          status: 'not_attended',
        ),
        HrAttendanceRecord(
          employee: employee,
          date: DateTime(2026, 9, 4),
          status: 'day_off',
          statusDetail: 'إجازة اعتيادية',
        ),
      ],
      requests: [
        HrRequestRecord(
          employee: employee,
          date: DateTime(2026, 9, 2),
          type: 'إذن تأخير حضور',
          status: 'approved',
          durationMinutes: 60,
        ),
        HrRequestRecord(
          employee: employee,
          date: DateTime(2026, 9, 4),
          type: 'إجازة اعتيادية',
          status: 'approved',
        ),
      ],
      deductions: [
        HrDeductionRecord(
          employee: employee,
          date: DateTime(2026, 9, 2),
          reason: 'تأخير حضور 30 دقيقة',
          status: 'approved',
          fraction: 0.25,
        ),
        HrDeductionRecord(
          employee: employee,
          date: DateTime(2026, 9, 3),
          reason: 'غياب دون تسجيل حضور',
          status: 'approved',
          fraction: 1.0,
        ),
        HrDeductionRecord(
          employee: employee,
          date: DateTime(2026, 9, 1),
          reason: 'عدم تسجيل الانصراف',
          status: 'approved',
          fraction: 0.25,
        ),
      ],
    );

    final summary = EmployeeDeductionSummaryItem.fromReport(
      employee: employee,
      report: report,
    );

    // Sign out deduction is excluded! Only late (0.25) and absence (1.0) are included.
    expect(summary.totalDeductionDays, 1.25);
    expect(summary.lateDeductionDays, 0.25);
    expect(summary.absentDeductionDays, 1.0);
    expect(summary.otherDeductionDays, 0.0);
    expect(summary.deductions.length, 2);
    expect(summary.deductions.any((d) => d.reason.contains('انصراف')), isFalse);

    // Permissions & Leaves counts
    expect(summary.permissionCount, 1);
    expect(summary.permissionMinutes, 60);
    expect(summary.leaveDays, 1);
    expect(summary.leaveRequestsCount, 1);
  });
}
