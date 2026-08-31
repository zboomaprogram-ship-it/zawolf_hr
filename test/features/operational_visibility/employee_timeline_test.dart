import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/operational_visibility/domain/entities/employee_timeline_query.dart';

void main() {
  test('timeline is bounded and uses the selected effective period', () {
    final query = EmployeeTimelineQuery(
      employeeUserId: 'employee-1',
      from: DateTime.utc(2026, 7, 1),
      to: DateTime.utc(2026, 7, 31, 23, 59),
      pageSize: 50,
    );
    expect(query.pageSize, 50);
    expect(query.from.month, 7);
    expect(query.to.month, 7);
  });

  test('timeline rejects unbounded page sizes and reversed periods', () {
    expect(
      () => EmployeeTimelineQuery(
        employeeUserId: 'employee-1',
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 7, 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => EmployeeTimelineQuery(
        employeeUserId: 'employee-1',
        from: DateTime.utc(2026, 7, 1),
        to: DateTime.utc(2026, 8, 1),
        pageSize: 101,
      ),
      throwsArgumentError,
    );
  });
}
