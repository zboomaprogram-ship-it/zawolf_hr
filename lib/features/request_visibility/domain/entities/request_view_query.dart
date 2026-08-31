import 'request_visibility_record.dart';

enum RequestViewTab { active, history, deductions, all }

final class RequestActorScope {
  const RequestActorScope({
    required this.actorId,
    required this.role,
    this.teamEmployeeIds = const <String>[],
  });

  final String actorId;
  final String role;
  final List<String> teamEmployeeIds;
}

final class RequestViewQuery {
  const RequestViewQuery({
    required this.actorScope,
    required this.tab,
    required this.fromDate,
    required this.toDate,
    this.employeeScopeIds = const <String>[],
    this.searchTerm = '',
    this.pageCursor,
    this.pageSize = 50,
  }) : assert(pageSize > 0 && pageSize <= 100);

  final RequestActorScope actorScope;
  final RequestViewTab tab;
  final DateTime fromDate;
  final DateTime toDate;
  final List<String> employeeScopeIds;
  final String searchTerm;
  final String? pageCursor;
  final int pageSize;

  bool matches(RequestVisibilityRecord record) {
    if (record.occurredAt.isBefore(fromDate) ||
        record.occurredAt.isAfter(toDate)) {
      return false;
    }
    if (employeeScopeIds.isNotEmpty &&
        !employeeScopeIds.contains(record.employeeId)) {
      return false;
    }
    return switch (tab) {
      RequestViewTab.active => !record.isHistorical,
      RequestViewTab.history => record.isHistorical,
      RequestViewTab.deductions =>
        record.sourceType == RequestSourceType.salaryDeduction ||
            record.sourceType == RequestSourceType.lateArrivalDeduction,
      RequestViewTab.all => true,
    };
  }
}
