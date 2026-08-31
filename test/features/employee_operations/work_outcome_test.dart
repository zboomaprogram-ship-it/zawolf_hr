import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/data/legacy_task_kpi_projection.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/work_outcome.dart';

void main() {
  WorkOutcome fixture({int version = 1}) => WorkOutcome(
    id: 'outcome-1',
    employeeUserId: 'employee-1',
    ownerUserId: 'manager-1',
    titleAr: 'متابعة العميل',
    targetValue: 10,
    progressValue: 4,
    status: WorkOutcomeStatus.inProgress,
    dueDate: DateTime(2026, 8, 25),
    version: version,
    legacyTaskId: 'task-1',
    legacyKpiId: 'kpi-1',
  );

  test('progress preserves legacy links and advances the version once', () {
    final updated = fixture().progress(value: 10, expectedVersion: 1);

    expect(updated.status, WorkOutcomeStatus.submitted);
    expect(updated.version, 2);
    expect(updated.legacyTaskId, 'task-1');
    expect(updated.legacyKpiId, 'kpi-1');
  });

  test('stale progress cannot silently overwrite another update', () {
    expect(
      () => fixture().progress(value: 5, expectedVersion: 0),
      throwsStateError,
    );
  });

  test('legacy task projection preserves outcome identity and version', () {
    const projection = LegacyTaskKpiProjection();
    final updated = fixture().progress(
      value: 7,
      expectedVersion: 1,
      evidenceReference: 'drive://evidence-1',
    );

    expect(projection.taskPatch(updated), {
      'actualValue': 7.0,
      'workOutcomeId': 'outcome-1',
      'workOutcomeVersion': 2,
      'workOutcomeStatus': 'inProgress',
      'attachmentUrl': 'drive://evidence-1',
    });
  });

  test('legacy KPI projection is deterministic for retry parity', () {
    const projection = LegacyTaskKpiProjection();
    final updated = fixture().progress(value: 10, expectedVersion: 1);

    expect(
      projection.kpiProjection(updated),
      projection.kpiProjection(updated),
    );
    expect(projection.kpiProjection(updated), containsPair('ratio', 1.0));
    expect(projection.kpiProjection(updated), containsPair('version', 2));
  });
}
