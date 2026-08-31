import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/work_outcome.dart';

/// Additive compatibility projection. Legacy history remains untouched; only
/// the linked record receives the latest outcome projection and version.
final class LegacyTaskKpiProjection {
  const LegacyTaskKpiProjection();

  void apply({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required WorkOutcome outcome,
    required bool taskExists,
    required bool kpiExists,
  }) {
    final taskId = outcome.legacyTaskId?.trim() ?? '';
    if (taskId.isNotEmpty && taskExists) {
      transaction.update(firestore.collection('tasks').doc(taskId), {
        ...taskPatch(outcome),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final kpiId = outcome.legacyKpiId?.trim() ?? '';
    if (kpiId.isNotEmpty && kpiExists) {
      transaction.update(firestore.collection('employeeKpis').doc(kpiId), {
        'workOutcomeProjections.${outcome.id}': kpiProjection(outcome),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Map<String, Object?> taskPatch(WorkOutcome outcome) => {
    'actualValue': outcome.progressValue,
    'workOutcomeId': outcome.id,
    'workOutcomeVersion': outcome.version,
    'workOutcomeStatus': outcome.status.name,
    if (outcome.evidenceReference != null)
      'attachmentUrl': outcome.evidenceReference,
  };

  Map<String, Object?> kpiProjection(WorkOutcome outcome) => {
    'actual': outcome.progressValue,
    'target': outcome.targetValue,
    'ratio': outcome.progressRatio,
    'status': outcome.status.name,
    'version': outcome.version,
    if (outcome.evidenceReference != null)
      'evidenceReference': outcome.evidenceReference,
  };
}
