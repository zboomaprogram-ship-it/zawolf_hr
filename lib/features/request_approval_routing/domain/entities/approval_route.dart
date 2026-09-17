import 'approval_stage.dart';

/// Pure domain entity representing an ordered sequential approval chain for a request.
class ApprovalRoute {
  const ApprovalRoute({
    required this.requestId,
    required this.requestType,
    required this.stages,
    this.currentApprovalIndex = 0,
    this.routeVersion = 1,
  });

  final String requestId;
  final String requestType;
  final List<ApprovalStage> stages;
  final int currentApprovalIndex;
  final int routeVersion;

  /// The active stage awaiting action, or null if all stages have settled.
  ApprovalStage? get currentStage =>
      currentApprovalIndex < stages.length ? stages[currentApprovalIndex] : null;

  /// Whether all stages in the route have been resolved.
  bool get isCompleted => currentApprovalIndex >= stages.length;

  /// Whether any stage in the route was rejected.
  bool get isRejected => stages.any((s) => s.state == ApprovalStageState.rejected);
}
