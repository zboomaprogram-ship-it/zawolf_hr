final class CompanyOsVersionConflict {
  const CompanyOsVersionConflict({
    required this.targetId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String targetId;
  final int expectedVersion;
  final int actualVersion;
}
