import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/work_outcome.dart';
import 'package:zawolf_hr/features/employee_operations/domain/repositories/work_outcome_repository.dart';
import 'package:zawolf_hr/features/employee_operations/presentation/pages/work_outcomes_page.dart';

void main() {
  WorkOutcome outcome({int version = 1}) => WorkOutcome(
    id: 'outcome-1',
    employeeUserId: 'employee-1',
    ownerUserId: 'manager-1',
    titleAr: 'متابعة العميل',
    targetValue: 10,
    progressValue: 4,
    status: WorkOutcomeStatus.inProgress,
    dueDate: DateTime(2026, 8, 25),
    version: version,
  );

  Widget app(_FakeWorkOutcomeRepository repository, {bool manager = false}) =>
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: WorkOutcomesPage(
            key: ValueKey(repository),
            actorUserId: manager ? 'manager-1' : 'employee-1',
            repository: repository,
            mode: manager
                ? WorkOutcomesPageMode.manager
                : WorkOutcomesPageMode.employee,
          ),
        ),
      );

  testWidgets('employee sees own outcome and updates progress once', (
    tester,
  ) async {
    final repository = _FakeWorkOutcomeRepository([outcome()]);
    await tester.pumpWidget(app(repository));
    await tester.pump();

    expect(repository.watchedEmployeeId, 'employee-1');
    expect(find.text('متابعة العميل'), findsOneWidget);
    await tester.tap(find.text('تحديث التقدم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('work-outcome-progress')), '7');
    await tester.tap(find.byKey(const Key('save-work-outcome-progress')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastProgress, 7);
  });

  testWidgets(
    'manager mode is scoped to owner and cannot edit employee result',
    (tester) async {
      final repository = _FakeWorkOutcomeRepository([outcome()]);
      await tester.pumpWidget(app(repository, manager: true));
      await tester.pump();

      expect(repository.watchedOwnerId, 'manager-1');
      expect(find.text('نتائج عمل الفريق'), findsOneWidget);
      expect(find.text('تحديث التقدم'), findsNothing);
    },
  );

  testWidgets('empty and interrupted states are Arabic and safe', (
    tester,
  ) async {
    final emptyRepository = _FakeWorkOutcomeRepository(const []);
    await tester.pumpWidget(app(emptyRepository));
    await tester.pump();
    expect(find.text('لا توجد نتائج عمل مسندة حالياً.'), findsOneWidget);

    final failedRepository = _FakeWorkOutcomeRepository(
      const [],
      watchError: Exception('cloud_firestore/unavailable'),
    );
    await tester.pumpWidget(app(failedRepository));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('تعذر تحميل نتائج العمل الآن. حاول مرة أخرى.'),
      findsWidgets,
    );
    expect(find.textContaining('cloud_firestore'), findsNothing);
  });

  testWidgets('optimistic conflict shows safe Arabic message', (tester) async {
    final repository = _FakeWorkOutcomeRepository([
      outcome(),
    ], updateError: StateError('تم تعديل نتيجة العمل من جهاز آخر.'));
    await tester.pumpWidget(app(repository));
    await tester.pump();
    await tester.tap(find.text('تحديث التقدم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('work-outcome-progress')), '7');
    await tester.tap(find.byKey(const Key('save-work-outcome-progress')));
    await tester.pumpAndSettle();

    expect(find.text('تم تعديل نتيجة العمل من جهاز آخر.'), findsOneWidget);
  });
}

final class _FakeWorkOutcomeRepository implements WorkOutcomeRepository {
  _FakeWorkOutcomeRepository(this.items, {this.watchError, this.updateError});

  final List<WorkOutcome> items;
  final Object? watchError;
  final Object? updateError;
  String? watchedEmployeeId;
  String? watchedOwnerId;
  int updateCalls = 0;
  double? lastProgress;

  Stream<List<WorkOutcome>> _stream() => watchError == null
      ? Stream<List<WorkOutcome>>.value(items)
      : Stream<List<WorkOutcome>>.error(watchError!);

  @override
  Stream<List<WorkOutcome>> watchForEmployee(String employeeUserId) {
    watchedEmployeeId = employeeUserId;
    return _stream();
  }

  @override
  Stream<List<WorkOutcome>> watchOwnedBy(String ownerUserId) {
    watchedOwnerId = ownerUserId;
    return _stream();
  }

  @override
  Future<WorkOutcome> updateProgress({
    required WorkOutcome outcome,
    required double progressValue,
    String? evidenceReference,
  }) async {
    updateCalls += 1;
    lastProgress = progressValue;
    if (updateError != null) throw updateError!;
    return outcome.progress(
      value: progressValue,
      expectedVersion: outcome.version,
      evidenceReference: evidenceReference,
    );
  }
}
