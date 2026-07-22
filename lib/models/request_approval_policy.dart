class RequestApprovalPolicy {
  final bool requireHrAfterManagerApproval;

  const RequestApprovalPolicy({this.requireHrAfterManagerApproval = false});

  factory RequestApprovalPolicy.fromMap(Map<String, dynamic>? data) {
    return RequestApprovalPolicy(
      requireHrAfterManagerApproval:
          data?['requireHrAfterManagerApproval'] as bool? ?? false,
    );
  }

  String get finalManagerApprovalStatus =>
      requireHrAfterManagerApproval ? 'pending_hr' : 'approved';
}
