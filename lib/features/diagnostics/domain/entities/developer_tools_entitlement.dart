/// A temporary, in-app entitlement for troubleshooting tools.
///
/// It deliberately has no attendance, device, location, USB, or mock-location
/// scope. Those protections remain enforced by the attendance service.
enum DeveloperToolScope {
  appDiagnostics,
  networkDiagnostics,
  releaseInformation,
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
