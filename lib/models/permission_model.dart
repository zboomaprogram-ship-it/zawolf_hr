import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionModel {
  final String permissionId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String locationId;
  final String managerId;
  final String permissionType; // early_leave | late_arrival | mid_shift_exit
  final String requestDate; // YYYY-MM-DD
  final String expectedTime; // HH:mm
  final int durationMinutes;
  final String reason;
  final String
  status; // 'pending_hr' | 'pending_manager' | 'approved' | 'rejected' | 'cancelled' | 'invalid_late'
  final bool isExceedingQuota;
  final bool isDeductible;
  final bool isSubmittedAfterWorkStart;
  final double salaryDeductionFraction;
  final double salaryDeductionAmount;
  final String salaryCurrency;
  final String salaryDeductionCode;
  final String salaryDeductionLabel;
  final String salaryDeductionApprovalStatus;
  final String monthKey; // YYYY-MM
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewerComment;
  final String? reviewerName;
  final DateTime? hrReviewedAt;
  final String? hrReviewedBy;
  final String? hrReviewerComment;
  final DateTime? managerReviewedAt;
  final String? managerReviewedBy;
  final String? managerReviewerComment;
  final bool isRead;

  PermissionModel({
    required this.permissionId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.locationId,
    required this.managerId,
    required this.permissionType,
    required this.requestDate,
    required this.expectedTime,
    required this.durationMinutes,
    required this.reason,
    required this.status,
    required this.isExceedingQuota,
    this.isDeductible = false,
    required this.isSubmittedAfterWorkStart,
    this.salaryDeductionFraction = 0,
    this.salaryDeductionAmount = 0,
    this.salaryCurrency = 'EGP',
    this.salaryDeductionCode = 'none',
    this.salaryDeductionLabel = 'لا يوجد خصم',
    this.salaryDeductionApprovalStatus = 'none',
    required this.monthKey,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerComment,
    this.reviewerName,
    this.hrReviewedAt,
    this.hrReviewedBy,
    this.hrReviewerComment,
    this.managerReviewedAt,
    this.managerReviewedBy,
    this.managerReviewerComment,
    this.isRead = false,
  });

  factory PermissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PermissionModel(
      permissionId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      permissionType: data['permissionType'] as String? ?? 'early_leave',
      requestDate: data['requestDate'] as String? ?? '',
      expectedTime: data['expectedTime'] as String? ?? '',
      durationMinutes: data['durationMinutes'] as int? ?? 0,
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? 'pending_hr',
      isExceedingQuota: data['isExceedingQuota'] as bool? ?? false,
      isDeductible: data['isDeductible'] as bool? ?? false,
      isSubmittedAfterWorkStart:
          data['isSubmittedAfterWorkStart'] as bool? ?? false,
      salaryDeductionFraction:
          (data['salaryDeductionFraction'] as num?)?.toDouble() ?? 0,
      salaryDeductionAmount:
          (data['salaryDeductionAmount'] as num?)?.toDouble() ?? 0,
      salaryCurrency: data['salaryCurrency'] as String? ?? 'EGP',
      salaryDeductionCode: data['salaryDeductionCode'] as String? ?? 'none',
      salaryDeductionLabel:
          data['salaryDeductionLabel'] as String? ?? 'لا يوجد خصم',
      salaryDeductionApprovalStatus:
          data['salaryDeductionApprovalStatus'] as String? ?? 'none',
      monthKey: data['monthKey'] as String? ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewerComment: data['reviewerComment'] as String?,
      reviewerName: data['reviewerName'] as String?,
      hrReviewedAt: (data['hrReviewedAt'] as Timestamp?)?.toDate(),
      hrReviewedBy: data['hrReviewedBy'] as String?,
      hrReviewerComment: data['hrReviewerComment'] as String?,
      managerReviewedAt: (data['managerReviewedAt'] as Timestamp?)?.toDate(),
      managerReviewedBy: data['managerReviewedBy'] as String?,
      managerReviewerComment: data['managerReviewerComment'] as String?,
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
      'permissionType': permissionType,
      'requestDate': requestDate,
      'expectedTime': expectedTime,
      'durationMinutes': durationMinutes,
      'reason': reason,
      'status': status,
      'isExceedingQuota': isExceedingQuota,
      'isDeductible': isDeductible,
      'isSubmittedAfterWorkStart': isSubmittedAfterWorkStart,
      'salaryDeductionFraction': salaryDeductionFraction,
      'salaryDeductionAmount': salaryDeductionAmount,
      'salaryCurrency': salaryCurrency,
      'salaryDeductionCode': salaryDeductionCode,
      'salaryDeductionLabel': salaryDeductionLabel,
      'salaryDeductionApprovalStatus': salaryDeductionApprovalStatus,
      'monthKey': monthKey,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewerComment != null) 'reviewerComment': reviewerComment,
      if (reviewerName != null) 'reviewerName': reviewerName,
      if (hrReviewedAt != null)
        'hrReviewedAt': Timestamp.fromDate(hrReviewedAt!),
      if (hrReviewedBy != null) 'hrReviewedBy': hrReviewedBy,
      if (hrReviewerComment != null) 'hrReviewerComment': hrReviewerComment,
      if (managerReviewedAt != null)
        'managerReviewedAt': Timestamp.fromDate(managerReviewedAt!),
      if (managerReviewedBy != null) 'managerReviewedBy': managerReviewedBy,
      if (managerReviewerComment != null)
        'managerReviewerComment': managerReviewerComment,
      'isRead': isRead,
    };
  }
}
