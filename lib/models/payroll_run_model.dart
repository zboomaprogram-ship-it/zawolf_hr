import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollStatus {
  static const draft = 'draft';
  static const reviewed = 'reviewed';
  static const locked = 'locked';

  static String arabicLabel(String value) {
    switch (value) {
      case reviewed:
        return 'تمت المراجعة';
      case locked:
        return 'مغلق';
      default:
        return 'مسودة';
    }
  }
}

class PayrollRunModel {
  final String payrollId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String managerId;
  final String monthKey;
  final String currency;
  final double baseSalary;
  final double attendanceDeductions;
  final double rewardsBonus;
  final double advances;
  final double netSalary;
  final int approvedDeductionCount;
  final int bonusRecordCount;
  final int advanceRecordCount;
  final String status;
  final DateTime? calculatedAt;
  final String calculatedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const PayrollRunModel({
    required this.payrollId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.managerId,
    required this.monthKey,
    required this.currency,
    required this.baseSalary,
    required this.attendanceDeductions,
    required this.rewardsBonus,
    required this.advances,
    required this.netSalary,
    required this.approvedDeductionCount,
    required this.bonusRecordCount,
    required this.advanceRecordCount,
    required this.status,
    required this.calculatedBy,
    this.calculatedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory PayrollRunModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PayrollRunModel(
      payrollId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      monthKey: data['monthKey'] as String? ?? '',
      currency: data['currency'] as String? ?? 'EGP',
      baseSalary: (data['baseSalary'] as num?)?.toDouble() ?? 0,
      attendanceDeductions:
          (data['attendanceDeductions'] as num?)?.toDouble() ?? 0,
      rewardsBonus: (data['rewardsBonus'] as num?)?.toDouble() ?? 0,
      advances: (data['advances'] as num?)?.toDouble() ?? 0,
      netSalary: (data['netSalary'] as num?)?.toDouble() ?? 0,
      approvedDeductionCount: data['approvedDeductionCount'] as int? ?? 0,
      bonusRecordCount: data['bonusRecordCount'] as int? ?? 0,
      advanceRecordCount: data['advanceRecordCount'] as int? ?? 0,
      status: data['status'] as String? ?? PayrollStatus.draft,
      calculatedBy: data['calculatedBy'] as String? ?? '',
      calculatedAt: (data['calculatedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'managerId': managerId,
      'monthKey': monthKey,
      'currency': currency,
      'baseSalary': baseSalary,
      'attendanceDeductions': attendanceDeductions,
      'rewardsBonus': rewardsBonus,
      'advances': advances,
      'netSalary': netSalary,
      'approvedDeductionCount': approvedDeductionCount,
      'bonusRecordCount': bonusRecordCount,
      'advanceRecordCount': advanceRecordCount,
      'status': status,
      'calculatedBy': calculatedBy,
      'calculatedAt': calculatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(calculatedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }

  static double calculateNetSalary({
    required double baseSalary,
    required double deductions,
    required double bonus,
    required double advances,
  }) {
    final value = baseSalary - deductions + bonus - advances;
    return value < 0 ? 0 : value;
  }
}
