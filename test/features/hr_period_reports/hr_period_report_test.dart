import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/hr_period_reports/domain/hr_period_report.dart';

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
}
