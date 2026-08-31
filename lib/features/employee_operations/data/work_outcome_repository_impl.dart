import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/work_outcome.dart';
import '../domain/repositories/work_outcome_repository.dart';
import 'legacy_task_kpi_projection.dart';

final class WorkOutcomeRepositoryImpl implements WorkOutcomeRepository {
  WorkOutcomeRepositoryImpl({
    FirebaseFirestore? firestore,
    LegacyTaskKpiProjection projection = const LegacyTaskKpiProjection(),
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _projection = projection;

  final FirebaseFirestore _db;
  final LegacyTaskKpiProjection _projection;

  @override
  Stream<List<WorkOutcome>> watchForEmployee(String employeeUserId) => _db
      .collection('work_outcomes')
      .where('employeeUserId', isEqualTo: employeeUserId)
      .limit(100)
      .snapshots()
      .map(_fromSnapshot);

  @override
  Stream<List<WorkOutcome>> watchOwnedBy(String ownerUserId) => _db
      .collection('work_outcomes')
      .where('ownerUserId', isEqualTo: ownerUserId)
      .limit(100)
      .snapshots()
      .map(_fromSnapshot);

  @override
  Future<WorkOutcome> updateProgress({
    required WorkOutcome outcome,
    required double progressValue,
    String? evidenceReference,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('work_outcomes').doc(outcome.id);
    final snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw StateError('نتيجة العمل غير موجودة.');
    }
    final current = _fromDocument(snapshot);
    if (current.employeeUserId != outcome.employeeUserId) {
      throw StateError('تعذر التحقق من مالك نتيجة العمل.');
    }
    final updated = current.progress(
      value: progressValue,
      expectedVersion: outcome.version,
      evidenceReference: evidenceReference,
    );
    final taskId = updated.legacyTaskId?.trim() ?? '';
    final kpiId = updated.legacyKpiId?.trim() ?? '';
    final taskExists =
        taskId.isNotEmpty &&
        (await transaction.get(_db.collection('tasks').doc(taskId))).exists;
    final kpiExists =
        kpiId.isNotEmpty &&
        (await transaction.get(
          _db.collection('employeeKpis').doc(kpiId),
        )).exists;
    transaction.update(ref, {
      'progressValue': updated.progressValue,
      'status': updated.status.name,
      'version': updated.version,
      'evidenceReference': updated.evidenceReference,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _projection.apply(
      transaction: transaction,
      firestore: _db,
      outcome: updated,
      taskExists: taskExists,
      kpiExists: kpiExists,
    );
    return updated;
  });

  List<WorkOutcome> _fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final outcomes = snapshot.docs.map(_fromDocument).toList()
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));
    return outcomes;
  }

  WorkOutcome _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WorkOutcome(
      id: doc.id,
      employeeUserId: data['employeeUserId'] as String? ?? '',
      ownerUserId: data['ownerUserId'] as String? ?? '',
      titleAr: data['titleAr'] as String? ?? '',
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 0,
      progressValue: (data['progressValue'] as num?)?.toDouble() ?? 0,
      status: _status(data['status'] as String?),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime(1970),
      version: (data['version'] as num?)?.toInt() ?? 0,
      legacyTaskId: data['legacyTaskId'] as String?,
      legacyKpiId: data['legacyKpiId'] as String?,
      evidenceReference: data['evidenceReference'] as String?,
    );
  }

  WorkOutcomeStatus _status(String? value) {
    for (final status in WorkOutcomeStatus.values) {
      if (status.name == value) return status;
    }
    return WorkOutcomeStatus.planned;
  }
}
