import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/approval_stage.dart';
import '../../domain/repositories/request_approval_routing_repository.dart';
import 'request_approval_routing_state.dart';

/// Presentation Cubit managing multi-stage approval routing forms and stage decisions.
/// Stays strictly presentation-focused and below 300 lines.
class RequestApprovalRoutingCubit extends Cubit<RequestApprovalRoutingState> {
  RequestApprovalRoutingCubit({
    required RequestApprovalRoutingRepository repository,
  })  : _repository = repository,
        super(const RequestApprovalRoutingState());

  final RequestApprovalRoutingRepository _repository;

  void updateApprovers(List<Map<String, String>> approvers) {
    emit(state.copyWith(
      selectedApprovers: approvers,
      status: ApprovalRoutingStatus.idle,
    ));
  }

  Future<bool> submitFieldMission({
    required List<String> employeeUids,
    required String missionDate,
    required String startTime,
    required String endTime,
    required String reason,
    String siteName = '',
    String locationId = '',
    bool requiresReturnToOffice = false,
    bool requiresCheckout = false,
  }) async {
    if (state.selectedApprovers.isEmpty) {
      emit(state.copyWith(
        status: ApprovalRoutingStatus.failure,
        errorMessage: 'يرجى تحديد معتمد واحد على الأقل للمسار.',
      ));
      return false;
    }

    emit(state.copyWith(status: ApprovalRoutingStatus.submitting));

    try {
      await _repository.createFieldMission(
        employeeUids: employeeUids,
        approvers: state.selectedApprovers,
        missionDate: missionDate,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
        siteName: siteName,
        locationId: locationId,
        requiresReturnToOffice: requiresReturnToOffice,
        requiresCheckout: requiresCheckout,
      );

      emit(state.copyWith(
        status: ApprovalRoutingStatus.success,
        successMessage: 'تم إنشاء مسار المأمورية بنجاح وإرسال الإشعارات للمعتمدين.',
      ));
      return true;
    } catch (error) {
      final safeMessage = error.toString().replaceFirst(
            RegExp(r'^(?:Exception|Bad state|StateError):\s*'),
            '',
          );
      emit(state.copyWith(
        status: ApprovalRoutingStatus.failure,
        errorMessage: safeMessage.isNotEmpty
            ? safeMessage
            : 'تعذر إرسال مسار الاعتماد. يرجى المحاولة لاحقاً.',
      ));
      return false;
    }
  }

  Future<bool> recordDecision({
    required String requestId,
    required String requestType,
    required String stageId,
    required ApprovalStageState decision,
    String? comment,
  }) async {
    emit(state.copyWith(status: ApprovalRoutingStatus.submitting));

    try {
      await _repository.recordStageDecision(
        requestId: requestId,
        requestType: requestType,
        stageId: stageId,
        decision: decision,
        comment: comment,
      );

      emit(state.copyWith(
        status: ApprovalRoutingStatus.success,
        successMessage: decision == ApprovalStageState.approved
            ? 'تم اعتماد المرحلة بنجاح وتحويل الطلب للمعتمد التالي.'
            : 'تم تسجيل رفض الطلب وإشعار صاحب الطلب.',
      ));
      return true;
    } catch (error) {
      final safeMessage = error.toString().replaceFirst(
            RegExp(r'^(?:Exception|Bad state|StateError):\s*'),
            '',
          );
      emit(state.copyWith(
        status: ApprovalRoutingStatus.failure,
        errorMessage: safeMessage.isNotEmpty
            ? safeMessage
            : 'تعذر حفظ قرار الاعتماد. يرجى إعادة المحاولة.',
      ));
      return false;
    }
  }
}
