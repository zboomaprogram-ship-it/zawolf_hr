import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/dashboard_attendance_summary_service.dart';

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
}
