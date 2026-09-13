/// A temporary, in-app entitlement for troubleshooting tools.
///
/// The attendance device override is an explicit, audited troubleshooting
/// exception. It only permits rebinding the entitled employee's own device;
/// location, biometric, account, and cross-account device protections remain
/// enforced by the attendance gateway.
enum DeveloperToolScope {
  appDiagnostics,
  networkDiagnostics,
  releaseInformation,
  attendanceDeviceOverride,
}

final class DeveloperToolsEntitlement {
  const DeveloperToolsEntitlement({
    required this.employeeUserId,
    required this.scopes,
    this.expiresAt,
    this.permanent = false,
    required this.grantedByUserId,
    this.revokedAt,
  });

  final String employeeUserId;
  final Set<DeveloperToolScope> scopes;
  final DateTime? expiresAt;
  final bool permanent;
  final String grantedByUserId;
  final DateTime? revokedAt;

  bool get isActive =>
      revokedAt == null &&
      scopes.isNotEmpty &&
      (permanent || (expiresAt?.isAfter(DateTime.now()) ?? false));

  bool allows(DeveloperToolScope scope) => isActive && scopes.contains(scope);
}
