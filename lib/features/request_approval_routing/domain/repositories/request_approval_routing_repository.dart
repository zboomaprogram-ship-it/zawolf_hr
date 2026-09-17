import '../entities/approval_stage.dart';

/// Pure domain repository contract governing sequential multi-stage request approvals.
abstract interface class RequestApprovalRoutingRepository {
  /// Creates a multi-stage field mission route requested by HR.
  Future<Map<String, dynamic>> createFieldMission({
    required List<String> employeeUids,
    required List<Map<String, String>> approvers,
    required String missionDate,
    required String startTime,
    required String endTime,
    required String reason,
    String siteName = '',
    String locationId = '',
    bool requiresReturnToOffice = false,
    bool requiresCheckout = false,
  });

  /// Transitions the current stage with an approved or rejected decision.
  Future<Map<String, dynamic>> recordStageDecision({
    required String requestId,
    required String requestType,
    required String stageId,
    required ApprovalStageState decision,
    String? comment,
  });
}
