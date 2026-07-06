import 'package:cloud_firestore/cloud_firestore.dart';

class AdvanceModel {
  final String advanceId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String locationId;
  final String managerId;
  final double amount;
  final String? reason;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String monthKey; // YYYY-MM
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewerComment;
  final bool isRead;

  AdvanceModel({
    required this.advanceId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.locationId,
    required this.managerId,
    required this.amount,
    this.reason,
    required this.status,
    required this.monthKey,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerComment,
    this.isRead = false,
  });

  factory AdvanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdvanceModel(
      advanceId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      reason: data['reason'] as String?,
      status: data['status'] as String? ?? 'pending',
      monthKey: data['monthKey'] as String? ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewerComment: data['reviewerComment'] as String?,
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'locationId': locationId,
      'managerId': managerId,
      'amount': amount,
      if (reason != null) 'reason': reason,
      'status': status,
      'monthKey': monthKey,
      'submittedAt': submittedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(submittedAt!),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewerComment != null) 'reviewerComment': reviewerComment,
      'isRead': isRead,
    };
  }
}
