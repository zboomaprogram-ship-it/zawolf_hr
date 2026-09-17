import '../domain/entities/approval_stage.dart';
import '../domain/repositories/request_approval_routing_repository.dart';
import 'request_approval_routing_gateway.dart';

/// Data implementation of [RequestApprovalRoutingRepository].
/// Delegates to the Hostinger gateway with transactional operation IDs.
class RequestApprovalRoutingRepositoryImpl implements RequestApprovalRoutingRepository {
  RequestApprovalRoutingRepositoryImpl({
    RequestApprovalRoutingGateway? gateway,
  }) : _gateway = gateway ?? RequestApprovalRoutingGateway();

  final RequestApprovalRoutingGateway _gateway;

  @override
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
  }) {
    return _gateway.createFieldMission(
      employeeUids: employeeUids,
      approvers: approvers,
      missionDate: missionDate,
      startTime: startTime,
      endTime: endTime,
      reason: reason,
      siteName: siteName,
      locationId: locationId,
      requiresReturnToOffice: requiresReturnToOffice,
      requiresCheckout: requiresCheckout,
    );
  }

  @override
  Future<Map<String, dynamic>> recordStageDecision({
    required String requestId,
    required String requestType,
    required String stageId,
    required ApprovalStageState decision,
    String? comment,
  }) {
    return _gateway.decideFieldMission(
      requestId: requestId,
      approved: decision == ApprovalStageState.approved,
      comment: comment ?? '',
    );
  }
}
