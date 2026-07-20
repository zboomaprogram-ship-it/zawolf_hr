import 'package:cloud_firestore/cloud_firestore.dart';

class ProductivityScoreModel {
  final String scoreId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String managerId;
  final String monthKey;
  final double attendanceScore;
  final double punctualityScore;
  final double taskCompletionScore;
  final double taskQualityScore;
  final double kpiScore;
  final bool hasTaskData;
  final bool hasTaskQualityData;
  final bool hasKpiData;
  final double overallScore;
  final int completedTasks;
  final int totalTasks;
  final int overdueTasks;
  final int absentDays;
  final int lateDays;
  final DateTime? calculatedAt;

  const ProductivityScoreModel({
    required this.scoreId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.managerId,
    required this.monthKey,
    required this.attendanceScore,
    required this.punctualityScore,
    required this.taskCompletionScore,
    required this.taskQualityScore,
    required this.kpiScore,
    this.hasTaskData = true,
    this.hasTaskQualityData = true,
    this.hasKpiData = true,
    required this.overallScore,
    required this.completedTasks,
    required this.totalTasks,
    required this.overdueTasks,
    required this.absentDays,
    required this.lateDays,
    this.calculatedAt,
  });

  String get statusLabel {
    if (overallScore >= 90) return 'ممتاز';
    if (overallScore >= 80) return 'قوي';
    if (overallScore >= 70) return 'جيد';
    if (overallScore >= 60) return 'يحتاج متابعة';
    return 'خطر';
  }

  factory ProductivityScoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductivityScoreModel(
      scoreId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      monthKey: data['monthKey'] as String? ?? '',
      attendanceScore: (data['attendanceScore'] as num?)?.toDouble() ?? 0,
      punctualityScore: (data['punctualityScore'] as num?)?.toDouble() ?? 0,
      taskCompletionScore:
          (data['taskCompletionScore'] as num?)?.toDouble() ?? 0,
      taskQualityScore: (data['taskQualityScore'] as num?)?.toDouble() ?? 0,
      kpiScore: (data['kpiScore'] as num?)?.toDouble() ?? 0,
      hasTaskData: data['hasTaskData'] as bool? ?? true,
      hasTaskQualityData: data['hasTaskQualityData'] as bool? ?? true,
      hasKpiData: data['hasKpiData'] as bool? ?? true,
      overallScore: (data['overallScore'] as num?)?.toDouble() ?? 0,
      completedTasks: data['completedTasks'] as int? ?? 0,
      totalTasks: data['totalTasks'] as int? ?? 0,
      overdueTasks: data['overdueTasks'] as int? ?? 0,
      absentDays: data['absentDays'] as int? ?? 0,
      lateDays: data['lateDays'] as int? ?? 0,
      calculatedAt: (data['calculatedAt'] as Timestamp?)?.toDate(),
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
      'attendanceScore': attendanceScore,
      'punctualityScore': punctualityScore,
      'taskCompletionScore': taskCompletionScore,
      'taskQualityScore': taskQualityScore,
      'kpiScore': kpiScore,
      'hasTaskData': hasTaskData,
      'hasTaskQualityData': hasTaskQualityData,
      'hasKpiData': hasKpiData,
      'overallScore': overallScore,
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'overdueTasks': overdueTasks,
      'absentDays': absentDays,
      'lateDays': lateDays,
      'calculatedAt': calculatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(calculatedAt!),
    };
  }

  static double calculateOverall({
    required double attendanceScore,
    required double punctualityScore,
    required double taskCompletionScore,
    required double taskQualityScore,
    required double kpiScore,
  }) {
    final value =
        (attendanceScore * 0.25) +
        (punctualityScore * 0.15) +
        (taskCompletionScore * 0.25) +
        (taskQualityScore * 0.15) +
        (kpiScore * 0.20);
    return value.clamp(0, 100).toDouble();
  }

  static double calculateAvailableOverall({
    required double attendanceScore,
    required double punctualityScore,
    double? taskCompletionScore,
    double? taskQualityScore,
    double? kpiScore,
  }) {
    final components = <(double, double)>[
      (attendanceScore, 0.25),
      (punctualityScore, 0.15),
      if (taskCompletionScore != null) (taskCompletionScore, 0.25),
      if (taskQualityScore != null) (taskQualityScore, 0.15),
      if (kpiScore != null) (kpiScore, 0.20),
    ];
    final totalWeight = components.fold<double>(
      0,
      (total, item) => total + item.$2,
    );
    if (totalWeight == 0) return 0;
    final weighted = components.fold<double>(
      0,
      (total, item) => total + (item.$1 * item.$2),
    );
    return (weighted / totalWeight).clamp(0, 100).toDouble();
  }
}
