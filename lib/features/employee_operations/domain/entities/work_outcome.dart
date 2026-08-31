/// One practical work result. It may project to one legacy task and one KPI,
/// but it never mutates or erases the historical task/KPI records.
enum WorkOutcomeStatus {
  planned,
  inProgress,
  submitted,
  accepted,
  returned,
  cancelled,
}

final class WorkOutcome {
  const WorkOutcome({
    required this.id,
    required this.employeeUserId,
    required this.ownerUserId,
    required this.titleAr,
    required this.targetValue,
    required this.progressValue,
    required this.status,
    required this.dueDate,
    required this.version,
    this.legacyTaskId,
    this.legacyKpiId,
    this.evidenceReference,
  });

  final String id;
  final String employeeUserId;
  final String ownerUserId;
  final String titleAr;
  final double targetValue;
  final double progressValue;
  final WorkOutcomeStatus status;
  final DateTime dueDate;
  final int version;
  final String? legacyTaskId;
  final String? legacyKpiId;
  final String? evidenceReference;

  bool get isComplete => status == WorkOutcomeStatus.accepted;
  double get progressRatio => targetValue <= 0
      ? 0
      : (progressValue / targetValue).clamp(0, 1).toDouble();

  WorkOutcome progress({
    required double value,
    required int expectedVersion,
    String? evidenceReference,
  }) {
    if (expectedVersion != version) {
      throw StateError(
        'تم تعديل نتيجة العمل من جهاز آخر. حدّث الصفحة ثم أعد المحاولة.',
      );
    }
    if (value < 0 || value > targetValue) {
      throw ArgumentError('قيمة التقدم يجب أن تكون بين صفر والهدف.');
    }
    if (status == WorkOutcomeStatus.accepted ||
        status == WorkOutcomeStatus.cancelled) {
      throw StateError('لا يمكن تعديل نتيجة عمل منتهية.');
    }
    return WorkOutcome(
      id: id,
      employeeUserId: employeeUserId,
      ownerUserId: ownerUserId,
      titleAr: titleAr,
      targetValue: targetValue,
      progressValue: value,
      status: value >= targetValue
          ? WorkOutcomeStatus.submitted
          : WorkOutcomeStatus.inProgress,
      dueDate: dueDate,
      version: version + 1,
      legacyTaskId: legacyTaskId,
      legacyKpiId: legacyKpiId,
      evidenceReference: evidenceReference ?? this.evidenceReference,
    );
  }
}
