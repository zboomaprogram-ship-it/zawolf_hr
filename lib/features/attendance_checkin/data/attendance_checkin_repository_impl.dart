import '../../../core/errors/errors.dart';
import '../domain/entities/check_in_action.dart';
import '../domain/entities/check_in_receipt.dart';
import '../domain/entities/check_in_status_resolution.dart';
import '../domain/entities/pending_check_in.dart';
import '../domain/repositories/attendance_check_in_repository.dart';
import 'attendance_checkin_failure_mapper.dart';
import 'checkin_pilot_metrics.dart';
import 'local/checkin_outbox.dart';
import 'remote/attendance_gateway_checkin_client.dart';

class AttendanceCheckInRepositoryImpl implements AttendanceCheckInRepository {
  AttendanceCheckInRepositoryImpl({
    required CheckInRemoteClient remote,
    required CheckInOutbox outbox,
    AttendanceCheckInFailureMapper failureMapper =
        const AttendanceCheckInFailureMapper(),
    Future<void> Function(Duration duration)? wait,
    CheckInPilotMetrics? metrics,
  }) : _remote = remote,
       _outbox = outbox,
       _failureMapper = failureMapper,
       _wait = wait ?? Future<void>.delayed,
       _metrics = metrics ?? CheckInPilotMetrics();

  static const _maximumAutomaticRetries = 2;

  final CheckInRemoteClient _remote;
  final CheckInOutbox _outbox;
  final AttendanceCheckInFailureMapper _failureMapper;
  final Future<void> Function(Duration duration) _wait;
  final CheckInPilotMetrics _metrics;

  @override
  Future<OperationResult<CheckInReceipt>> submit(CheckInAction action) async {
    for (var attempt = 0; attempt <= _maximumAutomaticRetries; attempt++) {
      try {
        final receipt = await _remote.submit(action);
        await _outbox.remove(action.actionId, action.employeeScopeId);
        _metrics.saved++;
        return OperationResult.success(receipt);
      } catch (error) {
        final failure = _failureMapper.map(error);
        if (failure.requiresStatusCheck) {
          await _savePending(
            action,
            PendingCheckInState.requiresAttention,
            attempt,
          );
          _metrics.requiresStatusCheck++;
          return OperationResult.failure(failure);
        }
        if (!failure.canRetrySafely) {
          _metrics.safeFailure++;
          return OperationResult.failure(failure);
        }
        if (attempt < _maximumAutomaticRetries) {
          await _wait(Duration(milliseconds: 250 * (attempt + 1)));
          continue;
        }
        await _savePending(action, PendingCheckInState.pending, attempt + 1);
        _metrics.pendingSync++;
        return OperationResult.failure(failure);
      }
    }
    throw StateError('Unreachable bounded retry state.');
  }

  @override
  Future<PendingCheckIn?> pendingFor(String employeeScopeId) {
    return _outbox.getForEmployee(employeeScopeId);
  }

  @override
  Future<CheckInStatusResolution> resolveStatus(CheckInAction action) {
    return _remote.resolveStatus(action);
  }

  @override
  Future<OperationResult<CheckInReceipt>?> synchronizePending(
    String employeeScopeId,
  ) async {
    final pending = await _outbox.getForEmployee(employeeScopeId);
    if (pending == null) return null;

    if (pending.state == PendingCheckInState.requiresAttention) {
      final resolution = await resolveStatus(pending.action);
      if (resolution == CheckInStatusResolution.recorded) {
        await _outbox.remove(pending.action.actionId, employeeScopeId);
        _metrics.saved++;
        return OperationResult.success(
          CheckInReceipt(
            attendanceId: pending.action.actionId,
            status: CheckInReceiptStatus.alreadyRecorded,
          ),
        );
      }
      if (resolution == CheckInStatusResolution.unavailable) {
        _metrics.requiresStatusCheck++;
        return OperationResult.failure(
          AppFailure(
            category: FailureCategory.temporaryService,
            recovery: RecoveryGuidance.checkStatusBeforeRetry,
            outcomeCertainty: OutcomeCertainty.unknown,
          ),
        );
      }
    }

    return submit(pending.action);
  }

  Future<void> _savePending(
    CheckInAction action,
    PendingCheckInState state,
    int attemptCount,
  ) {
    return _outbox.put(
      PendingCheckIn(
        action: action,
        state: state,
        attemptCount: attemptCount,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
