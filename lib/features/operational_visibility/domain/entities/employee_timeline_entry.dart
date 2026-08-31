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
    this.nextCursor,
  });

  final List<EmployeeTimelineEntry> items;
  final bool hasMore;
  final String? nextCursor;
}
