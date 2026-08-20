import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/attendance_checkin_repository_impl.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/checkin_pilot_metrics.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/local/checkin_outbox.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/remote/attendance_gateway_checkin_client.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_action.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_receipt.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_status_resolution.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/pending_check_in.dart';
import 'package:zawolf_hr/services/attendance_gateway_service.dart';

void main() {
  final action = CheckInAction(
    actionId: 'employee-1_2026-08-20',
    employeeScopeId: 'employee-1',
    dateKey: '2026-08-20',
    capturedAt: DateTime.utc(2026, 8, 20),
    payload: const {'attendanceId': 'employee-1_2026-08-20'},
  );

  test(
    'retries a temporary failure twice then retains the original action',
    () async {
      final outbox = _MemoryOutbox();
      final remote = _FakeRemote(
        submitError: const AttendanceGatewayException('network', 'hidden'),
      );
      final repository = AttendanceCheckInRepositoryImpl(
        remote: remote,
        outbox: outbox,
        wait: (_) async {},
      );

      final result = await repository.submit(action);

      expect(result.isSuccess, isFalse);
      expect(remote.submissions, 3);
      expect(outbox.value?.action.actionId, action.actionId);
      expect(outbox.value?.state, PendingCheckInState.pending);
    },
  );

  test('does not retry or queue a confirmed access failure', () async {
    final outbox = _MemoryOutbox();
    final remote = _FakeRemote(
      submitError: const AttendanceGatewayException(
        'device_mismatch',
        'hidden',
      ),
    );
    final repository = AttendanceCheckInRepositoryImpl(
      remote: remote,
      outbox: outbox,
      wait: (_) async {},
    );

    final result = await repository.submit(action);

    expect(result.failureOrNull?.category, FailureCategory.access);
    expect(remote.submissions, 1);
    expect(outbox.value, isNull);
  });

  test('turns an interrupted result into status-check state', () async {
    final outbox = _MemoryOutbox();
    final repository = AttendanceCheckInRepositoryImpl(
      remote: _FakeRemote(
        submitError: const AttendanceGatewayException(
          'unknown_outcome',
          'hidden',
        ),
      ),
      outbox: outbox,
      wait: (_) async {},
    );

    final result = await repository.submit(action);

    expect(result.failureOrNull?.requiresStatusCheck, isTrue);
    expect(outbox.value?.state, PendingCheckInState.requiresAttention);
  });

  test(
    'records aggregate-only pilot outcomes without employee diagnostics',
    () async {
      final metrics = CheckInPilotMetrics();
      final repository = AttendanceCheckInRepositoryImpl(
        remote: _FakeRemote(),
        outbox: _MemoryOutbox(),
        metrics: metrics,
      );

      await repository.submit(action);

      expect(metrics.snapshot(), <String, int>{
        'saved': 1,
        'pendingSync': 0,
        'requiresStatusCheck': 0,
        'safeFailure': 0,
      });
    },
  );
}

class _MemoryOutbox implements CheckInOutbox {
  PendingCheckIn? value;

  @override
  Future<PendingCheckIn?> getForEmployee(String employeeScopeId) async =>
      value?.action.employeeScopeId == employeeScopeId ? value : null;

  @override
  Future<void> put(PendingCheckIn item) async => value = item;

  @override
  Future<void> remove(String actionId, String employeeScopeId) async {
    if (value?.action.actionId == actionId &&
        value?.action.employeeScopeId == employeeScopeId) {
      value = null;
    }
  }
}

class _FakeRemote implements CheckInRemoteClient {
  _FakeRemote({this.submitError});

  final Object? submitError;
  int submissions = 0;

  @override
  Future<CheckInReceipt> submit(CheckInAction action) async {
    submissions++;
    if (submitError != null) throw submitError!;
    return CheckInReceipt(
      attendanceId: action.actionId,
      status: CheckInReceiptStatus.recorded,
    );
  }

  @override
  Future<CheckInStatusResolution> resolveStatus(CheckInAction action) async =>
      CheckInStatusResolution.notRecorded;
}
