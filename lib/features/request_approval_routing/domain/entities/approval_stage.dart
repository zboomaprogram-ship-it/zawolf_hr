/// Lifecycle state of an individual approval stage.
enum ApprovalStageState {
  pending,
  approved,
  rejected,
  skipped;

  static ApprovalStageState fromString(String? value) => switch (value) {
        'approved' => ApprovalStageState.approved,
        'rejected' => ApprovalStageState.rejected,
        'skipped' => ApprovalStageState.skipped,
        _ => ApprovalStageState.pending,
      };

  String get serialized => switch (this) {
        ApprovalStageState.approved => 'approved',
        ApprovalStageState.rejected => 'rejected',
        ApprovalStageState.skipped => 'skipped',
        ApprovalStageState.pending => 'pending',
      };
}

/// Pure domain entity representing a single ordered step in a request approval route.
class ApprovalStage {
  const ApprovalStage({
    required this.stageId,
    required this.order,
    required this.approverId,
    required this.approverName,
    required this.approverRole,
    required this.labelAr,
    this.state = ApprovalStageState.pending,
    this.actedAt,
    this.comment,
  });

  final String stageId;
  final int order;
  final String approverId;
  final String approverName;
  final String approverRole;
  final String labelAr;
  final ApprovalStageState state;
  final DateTime? actedAt;
  final String? comment;

  ApprovalStage copyWith({
    ApprovalStageState? state,
    DateTime? actedAt,
    String? comment,
  }) =>
      ApprovalStage(
        stageId: stageId,
        order: order,
        approverId: approverId,
        approverName: approverName,
        approverRole: approverRole,
        labelAr: labelAr,
        state: state ?? this.state,
        actedAt: actedAt ?? this.actedAt,
        comment: comment ?? this.comment,
      );
}
