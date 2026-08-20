import '../../../core/errors/errors.dart';
import '../../../services/attendance_gateway_service.dart';

class AttendanceCheckInFailureMapper {
  const AttendanceCheckInFailureMapper();

  AppFailure map(Object error) {
    if (error is AttendanceGatewayException) {
      return switch (error.code) {
        'unauthenticated' => _failure(
          FailureCategory.authenticationSession,
          RecoveryGuidance.signInAgain,
        ),
        'network' => _failure(
          FailureCategory.connectivity,
          RecoveryGuidance.retrySafely,
        ),
        'timeout' || 'server_unavailable' => _failure(
          FailureCategory.temporaryService,
          RecoveryGuidance.retrySafely,
        ),
        'unknown_outcome' => _failure(
          FailureCategory.temporaryService,
          RecoveryGuidance.checkStatusBeforeRetry,
          certainty: OutcomeCertainty.unknown,
        ),
        'device_conflict' ||
        'device_mismatch' ||
        'account_inactive' => _failure(
          FailureCategory.access,
          RecoveryGuidance.contactResponsibleTeam,
        ),
        'invalid_request' ||
        'stale_event' ||
        'checkin_missing' ||
        'invalid_receipt' => _failure(
          FailureCategory.validation,
          RecoveryGuidance.correctInput,
        ),
        _ => _failure(
          FailureCategory.unexpected,
          RecoveryGuidance.checkStatusBeforeRetry,
          certainty: OutcomeCertainty.unknown,
        ),
      };
    }
    return _failure(
      FailureCategory.unexpected,
      RecoveryGuidance.checkStatusBeforeRetry,
      certainty: OutcomeCertainty.unknown,
    );
  }

  AppFailure _failure(
    FailureCategory category,
    RecoveryGuidance recovery, {
    OutcomeCertainty certainty = OutcomeCertainty.confirmedNotCompleted,
  }) => AppFailure(
    category: category,
    recovery: recovery,
    outcomeCertainty: certainty,
  );
}
