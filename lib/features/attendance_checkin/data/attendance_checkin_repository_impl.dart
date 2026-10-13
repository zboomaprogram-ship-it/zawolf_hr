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
import '../../diagnostics/domain/entities/diagnostic_event.dart';
import '../../diagnostics/domain/repositories/diagnostics_repository.dart';

class AttendanceCheckInRepositoryImpl implements AttendanceCheckInRepository {
  AttendanceCheckInRepositoryImpl({
    required CheckInRemoteClient remote,
    required CheckInOutbox outbox,
    AttendanceCheckInFailureMapper failureMapper =
        const AttendanceCheckInFailureMapper(),
    Future<void> Function(Duration duration)? wait,
    CheckInPilotMetrics? metrics,
    DiagnosticsRepository? diagnostics,
  }) : _remote = remote,
       _outbox = outbox,
       _failureMapper = failureMapper,
       _wait = wait ?? Future<void>.delayed,
       _metrics = metrics ?? CheckInPilotMetrics(),
       _diagnostics = diagnostics;

  static const _maximumAutomaticRetries = 2;

  final CheckInRemoteClient _remote;
  final CheckInOutbox _outbox;
  final AttendanceCheckInFailureMapper _failureMapper;
  final Future<void> Function(Duration duration) _wait;
  final CheckInPilotMetrics _metrics;
  final DiagnosticsRepository? _diagnostics;

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
        await _diagnostics?.report(
          DiagnosticEvent.create(
            feature: 'attendance_checkin',
            safeCode: _safeCode(failure),
            release: const String.fromEnvironment(
              'APP_RELEASE',
              defaultValue: 'unknown',
            ),
            occurredAt: DateTime.now(),
            metadata: const {'operation': 'submit', 'surface': 'attendance'},
          ),
        );
        if (failure.requiresStatusCheck) {
          // Attendance is online-only. Never retain an ambiguous event for a
          // later automatic submission; the employee must retry live.
          await _outbox.remove(action.actionId, action.employeeScopeId);
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
        // Do not queue attendance locally after online retries fail. A later
        // replay could incorrectly convert a failed live check-in into a late
        // or unreviewed attendance event.
        await _outbox.remove(action.actionId, action.employeeScopeId);
        _metrics.safeFailure++;
        return OperationResult.failure(failure);
      }
    }
    throw StateError('Unreachable bounded retry state.');
  }

  String _safeCode(AppFailure failure) => switch (failure.category) {
    FailureCategory.authenticationSession => 'session_expired',
    FailureCategory.access => 'access_denied',
    FailureCategory.connectivity => 'connection_interrupted',
    FailureCategory.validation => 'validation_failed',
    FailureCategory.temporaryService =>
      failure.requiresStatusCheck
          ? 'check_request_status'
          : 'temporarily_unavailable',
    _ => 'unexpected',
  };

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

    // Older releases could retain a failed event locally. Discard it instead
    // of replaying attendance after the employee is no longer present.
    await _outbox.remove(pending.action.actionId, employeeScopeId);
    return null;
  }
}
