import 'package:cloud_firestore/cloud_firestore.dart';

class FieldAssignmentModel {
  final String assignmentId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String locationId;
  final String date;
  final String startTime;
  final String endTime;
  final String reason;
  final String siteName;
  final bool requiresReturnToOffice;
  final bool requiresCheckout;
  final String status;
  final String createdBy;
  final DateTime? createdAt;

  const FieldAssignmentModel({
    required this.assignmentId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.locationId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.siteName,
    required this.requiresReturnToOffice,
    required this.requiresCheckout,
    required this.status,
    required this.createdBy,
    this.createdAt,
  });

  factory FieldAssignmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return FieldAssignmentModel(
      assignmentId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      siteName: data['siteName'] as String? ?? '',
      requiresReturnToOffice: data['requiresReturnToOffice'] as bool? ?? true,
      requiresCheckout: data['requiresCheckout'] as bool? ?? true,
      status: data['status'] as String? ?? 'active',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'department': department,
    'locationId': locationId,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'reason': reason,
    'siteName': siteName,
    'requiresReturnToOffice': requiresReturnToOffice,
    'requiresCheckout': requiresCheckout,
    'status': status,
    'createdBy': createdBy,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
  };
}
