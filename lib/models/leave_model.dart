import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String leaveId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String locationId;
  final String managerId;
  final String leaveType; // day_off | sick | casual | unpaid | exam | remote
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final String? reason;
  final String? attachmentUrl;
  final String workHandoverTo;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewerComment;
  final String? reviewerName;
  final bool isRead;

  LeaveModel({
    required this.leaveId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.locationId,
    required this.managerId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    this.reason,
    this.attachmentUrl,
    this.workHandoverTo = '',
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerComment,
    this.reviewerName,
    this.isRead = false,
  });

  factory LeaveModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveModel(
      leaveId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      leaveType: data['leaveType'] as String? ?? 'annual',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      numberOfDays: data['numberOfDays'] as int? ?? 1,
      reason: data['reason'] as String?,
      attachmentUrl: data['attachmentUrl'] as String?,
      workHandoverTo: data['workHandoverTo'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewerComment: data['reviewerComment'] as String?,
      reviewerName: data['reviewerName'] as String?,
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
      'leaveType': leaveType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfDays': numberOfDays,
      if (reason != null) 'reason': reason,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      'workHandoverTo': workHandoverTo,
      'status': status,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewerComment != null) 'reviewerComment': reviewerComment,
      if (reviewerName != null) 'reviewerName': reviewerName,
      'isRead': isRead,
    };
  }
}
