import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/data/legacy_task_kpi_projection.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/work_outcome.dart';

void main() {
  test('KPI streams are bounded to the selected month and ownership scope', () {
    final source = File('lib/services/kpi_service.dart').readAsStringSync();

    expect(source, contains(".where('userId', isEqualTo: user.uid)"));
    expect(source, contains(".where('monthKey', isEqualTo: monthKey)"));
    expect(source, contains("base.where('teamLeaderId', isEqualTo: user.uid)"));
    expect(
      source,
      contains("base.where('managerIds', arrayContains: user.uid)"),
    );
  });

  test('KPI snapshot transforms do not re-read a whole month', () {
    final source = File('lib/services/kpi_service.dart').readAsStringSync();
    final streamStart = source.indexOf(
      'Stream<List<EmployeeKpiModel>> watchMyKpis',
    );
    final streamEnd = source.indexOf(
      'Stream<List<EmployeeKpiModel>> watchManagedKpis',
    );
    final watchMyKpis = source.substring(streamStart, streamEnd);

    expect(watchMyKpis, isNot(contains('.asyncMap')));
    expect(watchMyKpis, isNot(contains('.get()')));
  });

  test('KPI management tabs share one listener for a reviewer and cycle', () {
    final source = File('lib/services/kpi_service.dart').readAsStringSync();

    expect(source, contains('_managedKpiStreams.putIfAbsent('));
    expect(source, contains('_shareWhileListened('));
    expect(source, contains('await upstream?.cancel()'));
  });

  test(
    'work outcome KPI projection keeps target, progress and version parity',
    () {
      const projection = LegacyTaskKpiProjection();
      final outcome = WorkOutcome(
        id: 'outcome-7',
        employeeUserId: 'employee-7',
        ownerUserId: 'manager-1',
        titleAr: 'إغلاق فرص المبيعات',
        targetValue: 20,
        progressValue: 10,
        status: WorkOutcomeStatus.inProgress,
        dueDate: DateTime(2026, 8, 31),
        version: 4,
        legacyKpiId: 'kpi-7',
      );

      expect(projection.kpiProjection(outcome), {
        'actual': 10.0,
        'target': 20.0,
        'ratio': 0.5,
        'status': 'inProgress',
        'version': 4,
      });
    },
  );
}
