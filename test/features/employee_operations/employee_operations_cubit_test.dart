import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/attendance_correction_draft.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/deduction_explanation.dart';
import 'package:zawolf_hr/features/employee_operations/domain/repositories/employee_operations_repository.dart';
import 'package:zawolf_hr/features/employee_operations/presentation/cubit/attendance_correction_cubit.dart';
import 'package:zawolf_hr/features/employee_operations/presentation/cubit/deduction_details_cubit.dart';

void main() {
  test('deduction Cubit maps an empty employee period explicitly', () async {
    final cubit = DeductionDetailsCubit(_FakeEmployeeOperationsRepository());
    cubit.watch(employeeUserId: 'employee', effectiveCycleKey: '2026-08');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, DeductionDetailsStatus.empty);
    await cubit.close();
  });

  test('correction Cubit preserves an already-pending safe state', () async {
    final cubit = AttendanceCorrectionCubit(
      _FakeEmployeeOperationsRepository(
        result: CorrectionSubmissionResult.alreadyPending,
      ),
    );
    await cubit.submit(
      employeeUserId: 'employee',
      draft: AttendanceCorrectionDraft.create(
        attendanceId: 'attendance',
        originalCheckIn: DateTime(2026, 8, 20, 9),
        requestedCheckIn: DateTime(2026, 8, 20, 8, 30),
        reason: 'ازدحام الطريق',
        operationId: 'operation-123',
      ),
    );
    expect(cubit.state.status, AttendanceCorrectionStatus.pending);
    await cubit.close();
  });
}

final class _FakeEmployeeOperationsRepository
    implements EmployeeOperationsRepository {
  _FakeEmployeeOperationsRepository({
    this.result = CorrectionSubmissionResult.submitted,
  });

  final CorrectionSubmissionResult result;

  @override
  Future<CorrectionSubmissionResult> submitAttendanceCorrection({
    required String employeeUserId,
    required AttendanceCorrectionDraft draft,
  }) async => result;

  @override
  Stream<List<DeductionExplanation>> watchDeductionExplanations({
    required String employeeUserId,
    required String effectiveCycleKey,
  }) => Stream<List<DeductionExplanation>>.value(const []);
}
