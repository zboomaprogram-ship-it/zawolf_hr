import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/hr_period_reports/domain/hr_period_report.dart';

void main() {
  test('custom report periods are inclusive and capped at 31 calendar days', () {
    final period = HrReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 10, 1));
    expect(period.days, 31);
    expect(() => HrReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 10, 2)), throwsArgumentError);
  });

  test('only approved deductions are marked as discipline affecting', () {
    const employee = HrReportEmployee(id: 'u1', name: 'موظف', code: 'E-1', department: 'HR');
    final pending = HrAttendanceRecord(employee: employee, date: DateTime(2026, 9, 1), status: 'late', deductionStatus: 'pending_hr');
    final approved = HrAttendanceRecord(employee: employee, date: DateTime(2026, 9, 2), status: 'late', deductionStatus: 'approved');
    expect(pending.approvedDeduction, isFalse);
    expect(approved.approvedDeduction, isTrue);
  });
}
