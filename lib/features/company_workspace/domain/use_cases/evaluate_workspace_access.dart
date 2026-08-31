import '../entities/workspace_access_grant.dart';
import '../entities/workspace_access_policy.dart';
import '../entities/workspace_capability.dart';

final class EvaluateWorkspaceAccess {
  const EvaluateWorkspaceAccess();

  bool call({
    required WorkspaceAccessPolicy policy,
    required WorkspaceCapability capability,
    required String resourceId,
    required Iterable<WorkspaceAccessGrant> grants,
  }) => policy.can(capability, resourceId, grants);
}
