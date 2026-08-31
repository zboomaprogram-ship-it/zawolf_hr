final class EmployeePortalSummary {
  const EmployeePortalSummary({
    required this.openTicketCount,
    required this.assignedAssetCount,
    required this.pendingRequestCount,
  });

  final int openTicketCount;
  final int assignedAssetCount;
  final int pendingRequestCount;
}
