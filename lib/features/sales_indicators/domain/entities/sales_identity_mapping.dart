enum SalesIdentityMappingStatus { mapped, unmapped, ambiguous }

final class SalesIdentityMapping {
  const SalesIdentityMapping({
    required this.providerRole,
    required this.providerKey,
    required this.providerEmployeeId,
    required this.status,
    this.userId = '',
    this.employeeId = '',
    this.employeeName = '',
    this.target = 0,
    this.actual = 0,
    this.finalKpi = 0,
  });

  final String providerRole;
  final String providerKey;
  final String providerEmployeeId;
  final SalesIdentityMappingStatus status;
  final String userId;
  final String employeeId;
  final String employeeName;

  /// Provider totals are intentionally kept beside the identity status so an
  /// unmapped row is visible to HR but is never attributed to a user.
  final double target;
  final double actual;
  final double finalKpi;

  bool get isMapped =>
      status == SalesIdentityMappingStatus.mapped && userId.isNotEmpty;
}
