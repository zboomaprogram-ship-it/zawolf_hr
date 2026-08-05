import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/payroll_cycle.dart';

class ManualDeductionModel {
  final String id;
  final String userId;
  final String employeeName;
  final String employeeId;
  final String department;
  final String managerId;
  final List<String> managerIds;
  final String createdBy;
  final String createdByName;
  final String createdByRole;
  final DateTime date;
  final String dateKey;
  final String monthKey;
  final double dayFraction;
  final String fractionLabel;
  final String reason;
  final String status; // 'pending_manager', 'pending_hr', 'approved', 'rejected'
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final String? rejectedByName;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ManualDeductionModel({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.employeeId,
    required this.department,
    required this.managerId,
    this.managerIds = const [],
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    required this.date,
    required this.dateKey,
    required this.monthKey,
    required this.dayFraction,
    required this.fractionLabel,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  static String getFractionLabel(double fraction) {
    if (fraction == 0.25) return 'ربع يوم (0.25)';
    if (fraction == 0.50) return 'نصف يوم (0.50)';
    if (fraction == 1.00) return 'يوم كامل (1.0)';
    if (fraction == 2.00) return 'يومان (2.0)';
    if (fraction == 3.00) return 'ثلاثة أيام (3.0)';
    final text = fraction == fraction.roundToDouble()
        ? fraction.toInt().toString()
        : fraction.toStringAsFixed(2);
    return '$text يوم';
  }

  factory ManualDeductionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dt = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final fraction = (data['dayFraction'] as num?)?.toDouble() ?? 1.0;
    return ManualDeductionModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      department: data['department'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      managerIds: (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [if ((data['managerId'] as String? ?? '').isNotEmpty) data['managerId'] as String],
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdByRole: data['createdByRole'] as String? ?? 'hr',
      date: dt,
      dateKey: data['dateKey'] as String? ?? '',
      monthKey: data['monthKey'] as String? ?? PayrollCycle.forDate(dt).key,
      dayFraction: fraction,
      fractionLabel: data['fractionLabel'] as String? ?? getFractionLabel(fraction),
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? 'pending_hr',
      approvedBy: data['approvedBy'] as String?,
      approvedByName: data['approvedByName'] as String?,
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedBy: data['rejectedBy'] as String?,
      rejectedByName: data['rejectedByName'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeName': employeeName,
      'employeeId': employeeId,
      'department': department,
      'managerId': managerId,
      'managerIds': managerIds.isNotEmpty ? managerIds : [managerId],
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'date': Timestamp.fromDate(date),
      'dateKey': dateKey,
      'monthKey': monthKey,
      'dayFraction': dayFraction,
      'fractionLabel': fractionLabel,
      'reason': reason,
      'status': status,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedByName != null) 'approvedByName': approvedByName,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectedByName != null) 'rejectedByName': rejectedByName,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
