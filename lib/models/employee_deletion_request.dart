import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeDeletionRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String requesterId;
  final String requesterName;
  final String requesterRole;
  final String reason;
  final String status;
  final DateTime? requestedAt;

  const EmployeeDeletionRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.reason,
    required this.status,
    this.requestedAt,
  });

  factory EmployeeDeletionRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return EmployeeDeletionRequest(
      id: document.id,
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      requesterId: data['requesterId'] as String? ?? '',
      requesterName: data['requesterName'] as String? ?? '',
      requesterRole: data['requesterRole'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? '',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
    );
  }
}
