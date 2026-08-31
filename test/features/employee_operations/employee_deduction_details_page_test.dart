import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/attendance_correction_draft.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/deduction_explanation.dart';
import 'package:zawolf_hr/features/employee_operations/domain/repositories/employee_operations_repository.dart';
import 'package:zawolf_hr/features/employee_operations/presentation/pages/employee_deduction_details_page.dart';
import 'package:zawolf_hr/theme/theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  testWidgets(
    'shows Arabic evidence and effective cycle for current employee',
    (tester) async {
      final repository = _FakeRepository(items: [_attendanceDeduction()]);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('تأخير حضور 40 دقيقة'), findsOneWidget);
      expect(find.text('دورة الاستحقاق: 2026-08'), findsOneWidget);
      expect(find.textContaining('cloud_firestore'), findsNothing);
      expect(repository.lastWatchedEmployeeId, 'employee-self');
    },
  );

  testWidgets('failure is Arabic and retry reloads the same employee only', (
    tester,
  ) async {
    final repository = _FakeRepository(failFirstWatch: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر تحميل الخصوم'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد خصوم مسجلة في هذه الدورة.'), findsOneWidget);
    expect(repository.watchCount, 2);
    expect(repository.watchedEmployeeIds, everyElement('employee-self'));
  });

  testWidgets('correction interruption becomes safe status without duplicate', (
    tester,
  ) async {
    final repository = _FakeRepository(
      items: [_attendanceDeduction()],
      throwOnSubmit: true,
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('late-correction-att-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('correction-time')),
      '08:30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'ازدحام مروري شديد',
    );
    await tester.tap(find.byKey(const ValueKey('submit-correction')));
    await tester.pumpAndSettle();

    expect(find.textContaining('راجع حالة طلباتك'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(repository.submitCount, 1);
    expect(repository.lastSubmittedEmployeeId, 'employee-self');
  });

  testWidgets('does not expose another employee selector or identifier', (
    tester,
  ) async {
    final repository = _FakeRepository(items: [_attendanceDeduction()]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('اختر الموظف'), findsNothing);
    expect(find.textContaining('employee-other'), findsNothing);
    expect(repository.lastWatchedEmployeeId, 'employee-self');
  });
}

Widget _app(_FakeRepository repository) => MaterialApp(
  theme: ZaWolfTheme.darkTheme,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: EmployeeDeductionDetailsPage(
      employeeUserId: 'employee-self',
      repository: repository,
      initialCycleKey: '2026-08',
    ),
  ),
);

DeductionExplanation _attendanceDeduction() => DeductionExplanation(
  sourceKey: 'attendance:att-1',
  effectiveDate: DateTime(2026, 8, 20),
  effectiveCycleKey: '2026-08',
  sourceLabelAr: 'الحضور والانصراف',
  reasonAr: 'تأخير حضور 40 دقيقة',
  fraction: 0.25,
  status: DeductionReviewStatus.approved,
  amount: 125,
  currency: 'EGP',
  originalCheckIn: DateTime(2026, 8, 20, 9, 40),
);

final class _FakeRepository implements EmployeeOperationsRepository {
  _FakeRepository({
    this.items = const [],
    this.failFirstWatch = false,
    this.throwOnSubmit = false,
  });

  final List<DeductionExplanation> items;
  final bool failFirstWatch;
  final bool throwOnSubmit;
  int watchCount = 0;
  int submitCount = 0;
  String? lastWatchedEmployeeId;
  String? lastSubmittedEmployeeId;
  final List<String> watchedEmployeeIds = [];

  @override
  Stream<List<DeductionExplanation>> watchDeductionExplanations({
    required String employeeUserId,
    required String effectiveCycleKey,
  }) {
    watchCount += 1;
    lastWatchedEmployeeId = employeeUserId;
    watchedEmployeeIds.add(employeeUserId);
    if (failFirstWatch && watchCount == 1) {
      return Stream<List<DeductionExplanation>>.error(
        StateError('cloud_firestore/permission-denied'),
      );
    }
    return Stream<List<DeductionExplanation>>.value(items);
  }

  @override
  Future<CorrectionSubmissionResult> submitAttendanceCorrection({
    required String employeeUserId,
    required AttendanceCorrectionDraft draft,
  }) async {
    submitCount += 1;
    lastSubmittedEmployeeId = employeeUserId;
    if (throwOnSubmit) throw StateError('cloud_firestore/unavailable');
    return CorrectionSubmissionResult.submitted;
  }
}
