import '../entities/developer_tools_entitlement.dart';

abstract interface class DeveloperToolsRepository {
  Future<DeveloperToolsEntitlement?> loadMyEntitlement();

  Future<void> grant({
    required String employeeUserId,
    required Set<DeveloperToolScope> scopes,
    DateTime? expiresAt,
    bool permanent = false,
  });

  Future<void> revoke(String employeeUserId);
}
