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

  /// Single-segment Firestore collection name corresponding to this record.
  String get collection {
    if (sourceReference.contains('/')) {
      final part = sourceReference.split('/').first.trim();
      if (part.isNotEmpty) return part;
    }
    return switch (sourceType) {
      RequestSourceType.leave => 'leaves',
      RequestSourceType.permission => 'permissions',
      RequestSourceType.advance => 'advances',
      RequestSourceType.administrative => 'administrativeRequests',
      RequestSourceType.resignation => 'resignations',
      RequestSourceType.attendanceCorrection => 'attendanceCorrectionRequests',
      RequestSourceType.complaint => 'complaints',
      RequestSourceType.employeeDeletion => 'employeeDeletionRequests',
      RequestSourceType.salaryDeduction => 'manual_deductions',
      RequestSourceType.lateArrivalDeduction => 'attendance',
      _ => sourceReference.isNotEmpty ? sourceReference : 'leaves',
    };
  }

  /// Safe document ID within [collection].
  String get documentId {
    if (stableId.trim().isNotEmpty) return stableId.trim();
    if (sourceReference.contains('/')) {
      final parts = sourceReference.split('/');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
    }
    return stableId;
  }
}
