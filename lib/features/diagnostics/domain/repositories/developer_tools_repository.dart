import '../entities/developer_tools_entitlement.dart';

abstract interface class DeveloperToolsRepository {
  Future<DeveloperToolsEntitlement?> loadMyEntitlement();

  /// HR/admin view of the currently active, diagnostics-only grants.
  Future<List<DeveloperToolsEntitlement>> loadActiveEntitlements();

  Future<void> grant({
    required String employeeUserId,
    required Set<DeveloperToolScope> scopes,
    DateTime? expiresAt,
    bool permanent = false,
  });

  Future<void> revoke(String employeeUserId);
}
