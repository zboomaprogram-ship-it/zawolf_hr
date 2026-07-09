import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String complaintId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String title;
  final String body;
  final String? attachmentUrl;
  final String status; // 'new' | 'reviewed' | 'closed'
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  const ComplaintModel({
    required this.complaintId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.title,
    required this.body,
    this.attachmentUrl,
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComplaintModel(
      complaintId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      attachmentUrl: data['attachmentUrl'] as String?,
      status: data['status'] as String? ?? 'new',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'title': title,
      'body': body,
      if (attachmentUrl != null && attachmentUrl!.trim().isNotEmpty)
        'attachmentUrl': attachmentUrl!.trim(),
      'status': status,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    };
  }
}
