import 'package:cloud_firestore/cloud_firestore.dart';

class AdministrativeRequestCategory {
  static const personalData = 'personal_data';
  static const employmentStatus = 'employment_status';
  static const softwareSubscription = 'software_subscription';
  static const equipment = 'equipment';
  static const other = 'other';

  static const values = [
    personalData,
    employmentStatus,
    softwareSubscription,
    equipment,
    other,
  ];

  static String arabicLabel(String value) => switch (value) {
    personalData => 'تعديل البيانات الشخصية',
    employmentStatus => 'تعديل الوضع الوظيفي',
    softwareSubscription => 'اشتراك برنامج أو خدمة',
    equipment => 'جهاز أو معدات',
    _ => 'طلب إداري آخر',
  };
}

class AdministrativeRequestModel {
  const AdministrativeRequestModel({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.category,
    required this.notes,
    required this.status,
    required this.submittedAt,
    this.attachmentUrl,
    this.managerId = '',
    this.reviewerName,
    this.reviewerComment,
  });

  final String id;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String category;
  final String notes;
  final String status;
  final DateTime submittedAt;
  final String? attachmentUrl;
  final String managerId;
  final String? reviewerName;
  final String? reviewerComment;

  factory AdministrativeRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdministrativeRequestModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      category:
          data['category'] as String? ?? AdministrativeRequestCategory.other,
      notes: data['notes'] as String? ?? '',
      status: data['status'] as String? ?? 'pending_manager',
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachmentUrl: data['attachmentUrl'] as String?,
      managerId: data['managerId'] as String? ?? '',
      reviewerName: data['reviewerName'] as String?,
      reviewerComment: data['reviewerComment'] as String?,
    );
  }
}
