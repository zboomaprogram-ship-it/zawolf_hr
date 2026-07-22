import 'package:cloud_firestore/cloud_firestore.dart';

class KpiMetricDirection {
  static const higherIsBetter = 'higher_is_better';
  static const lowerIsBetter = 'lower_is_better';
  static const passFail = 'pass_fail';

  static const values = [higherIsBetter, lowerIsBetter, passFail];

  static String normalize(String? value) {
    return values.contains(value) ? value! : higherIsBetter;
  }

  static String arabicLabel(String value) {
    switch (normalize(value)) {
      case lowerIsBetter:
        return 'الأقل أفضل';
      case passFail:
        return 'نجاح / عدم نجاح';
      default:
        return 'الأعلى أفضل';
    }
  }
}

class KpiStatus {
  static const active = 'active';
  static const finalized = 'finalized';
}

class KpiMetricTemplate {
  final String name;
  final String unit;
  final double target;
  final double weight;
  final String direction;

  const KpiMetricTemplate({
    required this.name,
    required this.unit,
    required this.target,
    required this.weight,
    this.direction = KpiMetricDirection.higherIsBetter,
  });

  factory KpiMetricTemplate.fromMap(Map<String, dynamic> map) {
    return KpiMetricTemplate(
      name: map['name'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      target: (map['target'] as num?)?.toDouble() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 1,
      direction: KpiMetricDirection.normalize(map['direction'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'target': target,
      'weight': weight,
      'direction': direction,
    };
  }
}

class KpiTemplateModel {
  final String templateId;
  final String title;
  final String department;
  final String companyLocationId;
  final String companyName;
  final String createdBy;
  final String createdByName;
  final bool isActive;
  final DateTime? createdAt;
  final List<KpiMetricTemplate> metrics;

  const KpiTemplateModel({
    required this.templateId,
    required this.title,
    required this.department,
    this.companyLocationId = '',
    this.companyName = '',
    required this.createdBy,
    required this.createdByName,
    required this.isActive,
    required this.metrics,
    this.createdAt,
  });

  factory KpiTemplateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return KpiTemplateModel(
      templateId: doc.id,
      title: data['title'] as String? ?? '',
      department: data['department'] as String? ?? '',
      companyLocationId: data['companyLocationId'] as String? ?? '',
      companyName: data['companyName'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      metrics:
          (data['metrics'] as List<dynamic>?)?.map((item) {
            return KpiMetricTemplate.fromMap(
              Map<String, dynamic>.from(item as Map),
            );
          }).toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'department': department,
      'companyLocationId': companyLocationId,
      'companyName': companyName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'isActive': isActive,
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}

class EmployeeKpiMetric {
  final String name;
  final String unit;
  final double target;
  final double actual;
  final double weight;
  final String direction;
  final String evidenceUrl;
  final String managerComment;

  const EmployeeKpiMetric({
    required this.name,
    required this.unit,
    required this.target,
    required this.actual,
    required this.weight,
    this.direction = KpiMetricDirection.higherIsBetter,
    this.evidenceUrl = '',
    this.managerComment = '',
  });

  double get completion {
    if (target <= 0) return 0;
    final normalizedDirection = KpiMetricDirection.normalize(direction);
    if (normalizedDirection == KpiMetricDirection.passFail) {
      return actual >= target ? 100 : 0;
    }
    final value = normalizedDirection == KpiMetricDirection.lowerIsBetter
        ? (actual <= 0 ? 150.0 : (target / actual) * 100)
        : (actual / target) * 100;
    if (value < 0) return 0;
    if (value > 150) return 150;
    return value;
  }

  factory EmployeeKpiMetric.fromMap(Map<String, dynamic> map) {
    return EmployeeKpiMetric(
      name: map['name'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      target: (map['target'] as num?)?.toDouble() ?? 0,
      actual: (map['actual'] as num?)?.toDouble() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 1,
      direction: KpiMetricDirection.normalize(map['direction'] as String?),
      evidenceUrl: map['evidenceUrl'] as String? ?? '',
      managerComment: map['managerComment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'target': target,
      'actual': actual,
      'weight': weight,
      'direction': direction,
      'evidenceUrl': evidenceUrl,
      'managerComment': managerComment,
    };
  }

  EmployeeKpiMetric copyWith({
    double? actual,
    String? evidenceUrl,
    String? managerComment,
  }) {
    return EmployeeKpiMetric(
      name: name,
      unit: unit,
      target: target,
      actual: actual ?? this.actual,
      weight: weight,
      direction: direction,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      managerComment: managerComment ?? this.managerComment,
    );
  }
}

class EmployeeKpiModel {
  final String employeeKpiId;
  final String templateId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String managerId;
  final List<String> managerIds;
  final String monthKey;
  final String status;
  final List<EmployeeKpiMetric> metrics;
  final double overallProgress;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String finalizedBy;
  final DateTime? finalizedAt;

  const EmployeeKpiModel({
    required this.employeeKpiId,
    required this.templateId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.managerId,
    this.managerIds = const [],
    required this.monthKey,
    required this.status,
    required this.metrics,
    required this.overallProgress,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.finalizedBy = '',
    this.finalizedAt,
  });

  factory EmployeeKpiModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeKpiModel(
      employeeKpiId: doc.id,
      templateId: data['templateId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      managerIds:
          (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [
            if ((data['managerId'] as String? ?? '').isNotEmpty)
              data['managerId'] as String,
          ],
      monthKey: data['monthKey'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      metrics:
          (data['metrics'] as List<dynamic>?)?.map((item) {
            return EmployeeKpiMetric.fromMap(
              Map<String, dynamic>.from(item as Map),
            );
          }).toList() ??
          [],
      overallProgress: (data['overallProgress'] as num?)?.toDouble() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      finalizedBy: data['finalizedBy'] as String? ?? '',
      finalizedAt: (data['finalizedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'templateId': templateId,
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'managerId': managerId,
      'managerIds': managerIds.isNotEmpty ? managerIds : [managerId],
      'monthKey': monthKey,
      'status': status,
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
      'overallProgress': overallProgress,
      'createdBy': createdBy,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
      if (finalizedBy.isNotEmpty) 'finalizedBy': finalizedBy,
      if (finalizedAt != null) 'finalizedAt': Timestamp.fromDate(finalizedAt!),
    };
  }

  static double calculateProgress(List<EmployeeKpiMetric> metrics) {
    if (metrics.isEmpty) return 0;
    final totalWeight = metrics.fold<double>(
      0,
      (total, item) => total + item.weight,
    );
    if (totalWeight <= 0) return 0;
    final weighted = metrics.fold<double>(
      0,
      (total, item) => total + (item.completion * item.weight),
    );
    final value = weighted / totalWeight;
    if (value > 100) return 100;
    return value;
  }
}
