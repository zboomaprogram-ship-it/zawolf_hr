enum RequestSourceType {
  leave,
  permission,
  attendanceCorrection,
  salaryDeduction,
  lateArrivalDeduction,
  advance,
  administrative,
  complaint,
  resignation,
  employeeDeletion,
  unknown,
}

enum RequestLifecycleState {
  pending,
  approved,
  rejected,
  cancelled,
  confirmed,
  unknown,
}

enum RequestApprovalStage { manager, ceo, hr, finalised, unknown }

/// A source-neutral, immutable record for request/history tabs. It never
/// mutates legacy documents merely to make them readable.
final class RequestVisibilityRecord {
  const RequestVisibilityRecord({
    required this.stableId,
    required this.sourceType,
    required this.employeeId,
    required this.approvalStage,
    required this.lifecycleState,
    required this.occurredAt,
    required this.sourceReference,
    this.employeeName,
    this.employeeCode,
    this.reason,
  });

  final String stableId;
  final RequestSourceType sourceType;
  final String employeeId;
  final RequestApprovalStage approvalStage;
  final RequestLifecycleState lifecycleState;
  final DateTime occurredAt;
  final String sourceReference;
  final String? employeeName;
  final String? employeeCode;
  final String? reason;

  bool get isHistorical => switch (lifecycleState) {
    RequestLifecycleState.approved ||
    RequestLifecycleState.rejected ||
    RequestLifecycleState.cancelled ||
    RequestLifecycleState.confirmed => true,
    _ => false,
  };
}
