enum EmployeeTimelineKind {
  attendance,
  leave,
  permission,
  correction,
  request,
  deduction,
  unknown,
}

final class EmployeeTimelineEntry {
  const EmployeeTimelineEntry({
    required this.stableId,
    required this.kind,
    required this.effectiveAt,
    required this.status,
    required this.source,
    this.summaryAr,
  });

  final String stableId;
  final EmployeeTimelineKind kind;
  final DateTime effectiveAt;
  final String status;
  final String source;
  final String? summaryAr;
}

final class EmployeeTimelinePage {
  const EmployeeTimelinePage({
    required this.items,
    required this.hasMore,
    this.summary = const EmployeeTimelineSummary(),
    this.nextCursor,
  });

  final List<EmployeeTimelineEntry> items;
  final bool hasMore;
  final EmployeeTimelineSummary summary;
  final String? nextCursor;
}

/// Informational totals for the selected period. These values do not alter
/// payroll, leave balances, or any approval decision.
final class EmployeeTimelineSummary {
  const EmployeeTimelineSummary({
    this.salaryDeductionDays = 0,
    this.leaveRequests = 0,
    this.permissionRequests = 0,
    this.otherRequests = 0,
  });

  final double salaryDeductionDays;
  final int leaveRequests;
  final int permissionRequests;
  final int otherRequests;
}
