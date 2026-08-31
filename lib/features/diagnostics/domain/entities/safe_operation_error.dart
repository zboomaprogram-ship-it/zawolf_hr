/// Stable application error codes allowed in employee-facing surfaces.
enum SafeOperationErrorCode {
  sessionExpired,
  accessDenied,
  temporarilyUnavailable,
  connectionInterrupted,
  alreadySubmitted,
  validationFailed,
  checkRequestStatus,
  unexpected,
}

final class SafeOperationError {
  const SafeOperationError({required this.code, this.operation = ''});

  final SafeOperationErrorCode code;
  final String operation;
}
