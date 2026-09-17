/// Status of an approval routing operation.
enum ApprovalRoutingStatus {
  idle,
  submitting,
  success,
  failure,
}

/// Immutable state for [RequestApprovalRoutingCubit].
class RequestApprovalRoutingState {
  const RequestApprovalRoutingState({
    this.status = ApprovalRoutingStatus.idle,
    this.errorMessage,
    this.successMessage,
    this.selectedApprovers = const [],
  });

  final ApprovalRoutingStatus status;
  final String? errorMessage;
  final String? successMessage;
  final List<Map<String, String>> selectedApprovers;

  bool get isSubmitting => status == ApprovalRoutingStatus.submitting;

  RequestApprovalRoutingState copyWith({
    ApprovalRoutingStatus? status,
    String? errorMessage,
    String? successMessage,
    List<Map<String, String>>? selectedApprovers,
  }) =>
      RequestApprovalRoutingState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        successMessage: successMessage,
        selectedApprovers: selectedApprovers ?? this.selectedApprovers,
      );
}
