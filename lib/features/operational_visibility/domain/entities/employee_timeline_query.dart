final class EmployeeTimelineQuery {
  EmployeeTimelineQuery({
    required this.employeeUserId,
    required this.from,
    required this.to,
    this.pageSize = 50,
    this.cursor,
  }) {
    if (employeeUserId.trim().isEmpty) {
      throw ArgumentError.value(employeeUserId, 'employeeUserId');
    }
    if (to.isBefore(from)) throw ArgumentError('to must not precede from');
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(pageSize, 'pageSize');
    }
  }

  final String employeeUserId;
  final DateTime from;
  final DateTime to;
  final int pageSize;
  final String? cursor;
}
