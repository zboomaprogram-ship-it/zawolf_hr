import 'package:cloud_firestore/cloud_firestore.dart';

class WarningRewardType {
  static const warning = 'warning';
  static const notice = 'notice';
  static const reward = 'reward';
  static const bonusRecommendation = 'bonus_recommendation';
  static const followUp = 'follow_up';

  static String arabicLabel(String value) {
    switch (value) {
      case reward:
        return 'مكافأة';
      case bonusRecommendation:
        return 'ترشيح بونص';
      case followUp:
        return 'متابعة';
      case notice:
        return 'لفت نظر';
      default:
        return 'إنذار';
    }
  }
}

class WarningRewardStatus {
  static const suggested = 'suggested';
  static const issued = 'issued';
  static const acknowledged = 'acknowledged';
  static const dismissed = 'dismissed';

  static String arabicLabel(String value) {
    switch (value) {
      case issued:
        return 'صادر';
      case acknowledged:
        return 'تم الاطلاع';
      case dismissed:
        return 'مرفوض';
      default:
        return 'مقترح';
    }
  }
}

class WarningRewardModel {
  final String recordId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String managerId;
  final List<String> managerIds;
  final String type;
  final String status;
  final String title;
  final String description;
  final String createdBy;
  final String createdByName;
  final String source;
  final String? monthKey;
  final double? productivityScore;
  final double amount;
  final String currency;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;

  const WarningRewardModel({
    required this.recordId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.managerId,
    this.managerIds = const [],
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdByName,
    required this.source,
    this.monthKey,
    this.productivityScore,
    this.amount = 0,
    this.currency = 'EGP',
    this.createdAt,
    this.acknowledgedAt,
  });

  factory WarningRewardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WarningRewardModel(
      recordId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      managerIds: (data['managerIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      type: data['type'] as String? ?? WarningRewardType.warning,
      status: data['status'] as String? ?? WarningRewardStatus.issued,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      source: data['source'] as String? ?? 'manual',
      monthKey: data['monthKey'] as String?,
      productivityScore: (data['productivityScore'] as num?)?.toDouble(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'EGP',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      acknowledgedAt: (data['acknowledgedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'managerId': managerId,
      'managerIds': managerIds,
      'type': type,
      'status': status,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'source': source,
      if (monthKey != null) 'monthKey': monthKey,
      if (productivityScore != null) 'productivityScore': productivityScore,
      'amount': amount,
      'currency': currency,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      if (acknowledgedAt != null)
        'acknowledgedAt': Timestamp.fromDate(acknowledgedAt!),
    };
  }
}
