import '../entities/work_outcome.dart';

/// A versioned work-result boundary. The implementation writes compatible
/// projections to legacy tasks/KPIs while their history remains available.
abstract interface class WorkOutcomeRepository {
  Stream<List<WorkOutcome>> watchForEmployee(String employeeUserId);

  Stream<List<WorkOutcome>> watchOwnedBy(String ownerUserId);

  Future<WorkOutcome> updateProgress({
    required WorkOutcome outcome,
    required double progressValue,
    String? evidenceReference,
  });
}
