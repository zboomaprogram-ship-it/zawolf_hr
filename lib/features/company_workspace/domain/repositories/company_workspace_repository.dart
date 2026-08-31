import '../entities/workspace_access_grant.dart';
import '../entities/workspace_capability.dart';
import '../entities/workspace_operation.dart';

abstract interface class CompanyWorkspaceRepository {
  Future<bool> canAccess({
    required String resourceId,
    required WorkspaceCapability capability,
  });

  Future<List<WorkspaceAccessGrant>> grantsFor(String resourceId);

  Future<WorkspaceOperation> submit(WorkspaceOperation operation);
}
