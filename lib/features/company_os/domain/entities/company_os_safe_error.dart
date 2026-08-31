enum CompanyOsSafeCode {
  accessDenied,
  invalidInput,
  conflict,
  capacityReached,
  temporaryUnavailable,
  statusCheckRequired,
  sessionExpired,
  unexpected,
}

final class CompanyOsSafeError implements Exception {
  const CompanyOsSafeError({
    required this.code,
    required this.arabicMessage,
    this.retryable = false,
  });

  final CompanyOsSafeCode code;
  final String arabicMessage;
  final bool retryable;

  @override
  String toString() => 'CompanyOsSafeError(${code.name})';
}
