import 'package:cloud_firestore/cloud_firestore.dart';

class ResignationModel {
  final String resignationId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String reason;
  final DateTime resignationDate;
  final String status;
  final String managerId;
  final List<String> managerIds;
  final List<String> managerNames;
  final int managerApprovalIndex;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final String? reviewerName;
  final String? reviewerComment;

  const ResignationModel({
    required this.resignationId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.reason,
    required this.resignationDate,
    required this.status,
    required this.managerId,
    this.managerIds = const [],
    this.managerNames = const [],
    this.managerApprovalIndex = 0,
    this.submittedAt,
    this.reviewedBy,
    this.reviewerName,
    this.reviewerComment,
  });

  factory ResignationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResignationModel(
      resignationId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      resignationDate:
          (data['resignationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending_manager',
      managerId: data['managerId'] as String? ?? '',
      managerIds: (data['managerIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      managerNames: (data['managerNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      managerApprovalIndex: data['managerApprovalIndex'] as int? ?? 0,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewerName: data['reviewerName'] as String?,
      reviewerComment: data['reviewerComment'] as String?,
    );
  }
}
