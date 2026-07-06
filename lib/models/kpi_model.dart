import 'package:cloud_firestore/cloud_firestore.dart';

class KpiMetricTemplate {
  final String name;
  final String unit;
  final double target;
  final double weight;

  const KpiMetricTemplate({
    required this.name,
    required this.unit,
    required this.target,
    required this.weight,
  });

  factory KpiMetricTemplate.fromMap(Map<String, dynamic> map) {
    return KpiMetricTemplate(
      name: map['name'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      target: (map['target'] as num?)?.toDouble() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'unit': unit, 'target': target, 'weight': weight};
  }
}

class KpiTemplateModel {
  final String templateId;
  final String title;
  final String department;
  final String createdBy;
  final String createdByName;
  final bool isActive;
  final DateTime? createdAt;
  final List<KpiMetricTemplate> metrics;

  const KpiTemplateModel({
    required this.templateId,
    required this.title,
    required this.department,
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

  const EmployeeKpiMetric({
    required this.name,
    required this.unit,
    required this.target,
    required this.actual,
    required this.weight,
  });

  double get completion {
    if (target <= 0) return 0;
    final value = (actual / target) * 100;
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'target': target,
      'actual': actual,
      'weight': weight,
    };
  }

  EmployeeKpiMetric copyWith({double? actual}) {
    return EmployeeKpiMetric(
      name: name,
      unit: unit,
      target: target,
      actual: actual ?? this.actual,
      weight: weight,
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
  final String monthKey;
  final String status;
  final List<EmployeeKpiMetric> metrics;
  final double overallProgress;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EmployeeKpiModel({
    required this.employeeKpiId,
    required this.templateId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.managerId,
    required this.monthKey,
    required this.status,
    required this.metrics,
    required this.overallProgress,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
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
