import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_action.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_presentation_state.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_receipt.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_status_resolution.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/pending_check_in.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/repositories/attendance_check_in_repository.dart';
import 'package:zawolf_hr/features/attendance_checkin/presentation/cubit/checkin_cubit.dart';

void main() {
  final action = CheckInAction(
    actionId: 'employee-1_2026-08-20',
    employeeScopeId: 'employee-1',
    dateKey: '2026-08-20',
    capturedAt: DateTime.utc(2026, 8, 20),
    payload: const {},
  );

  test('shows saved for a recorded or duplicate check-in', () async {
    final cubit = CheckInCubit(
      _FakeRepository(
        result: const OperationResult.success(
          CheckInReceipt(
            attendanceId: 'employee-1_2026-08-20',
            status: CheckInReceiptStatus.alreadyRecorded,
          ),
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.submit(action);

    expect(cubit.state.status, CheckInViewStatus.saved);
    expect(cubit.state.receipt?.status, CheckInReceiptStatus.alreadyRecorded);
  });

  test(
    'shows pending sync after a safely retryable temporary failure',
    () async {
      final cubit = CheckInCubit(
        _FakeRepository(
          result: OperationResult.failure(
            AppFailure(
              category: FailureCategory.temporaryService,
              recovery: RecoveryGuidance.retrySafely,
              outcomeCertainty: OutcomeCertainty.confirmedNotCompleted,
            ),
          ),
          pending: PendingCheckIn(
            action: action,
            state: PendingCheckInState.pending,
            attemptCount: 3,
            updatedAt: DateTime.utc(2026, 8, 20),
          ),
        ),
      );
      addTearDown(cubit.close);

      await cubit.submit(action);

      expect(cubit.state.status, CheckInViewStatus.pendingSync);
    },
  );

  test('synchronizes a pending action on explicit screen entry', () async {
    final cubit = CheckInCubit(
      _FakeRepository(
        result: OperationResult.failure(
          AppFailure(
            category: FailureCategory.temporaryService,
            recovery: RecoveryGuidance.retrySafely,
            outcomeCertainty: OutcomeCertainty.confirmedNotCompleted,
          ),
        ),
        synchronizeResult: const OperationResult.success(
          CheckInReceipt(
            attendanceId: 'employee-1_2026-08-20',
            status: CheckInReceiptStatus.alreadyRecorded,
          ),
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.synchronizePending('employee-1');

    expect(cubit.state.status, CheckInViewStatus.saved);
  });

  test('requires a status check after an uncertain result', () async {
    final cubit = CheckInCubit(
      _FakeRepository(
        result: OperationResult.failure(
          AppFailure(
            category: FailureCategory.temporaryService,
            recovery: RecoveryGuidance.checkStatusBeforeRetry,
            outcomeCertainty: OutcomeCertainty.unknown,
          ),
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.submit(action);

    expect(cubit.state.status, CheckInViewStatus.requiresStatusCheck);
  });

  test(
    'does not submit a second action while status check is required',
    () async {
      final repository = _FakeRepository(
        result: OperationResult.failure(
          AppFailure(
            category: FailureCategory.temporaryService,
            recovery: RecoveryGuidance.checkStatusBeforeRetry,
            outcomeCertainty: OutcomeCertainty.unknown,
          ),
        ),
      );
      final cubit = CheckInCubit(repository);
      addTearDown(cubit.close);

      await cubit.submit(action);
      await cubit.submit(action);

      expect(repository.submissions, 1);
    },
  );
}

class _FakeRepository implements AttendanceCheckInRepository {
  _FakeRepository({required this.result, this.pending, this.synchronizeResult});

  final OperationResult<CheckInReceipt> result;
  final PendingCheckIn? pending;
  final OperationResult<CheckInReceipt>? synchronizeResult;
  int submissions = 0;

  @override
  Future<PendingCheckIn?> pendingFor(String employeeScopeId) async => pending;

  @override
  Future<CheckInStatusResolution> resolveStatus(CheckInAction action) async =>
      CheckInStatusResolution.notRecorded;

  @override
  Future<OperationResult<CheckInReceipt>> submit(CheckInAction action) async {
    submissions++;
    return result;
  }

  @override
  Future<OperationResult<CheckInReceipt>?> synchronizePending(
    String employeeScopeId,
  ) async => synchronizeResult;
}
