import 'workspace_access_grant.dart';
import 'workspace_capability.dart';

final class WorkspaceAccessPolicy {
  const WorkspaceAccessPolicy({
    required this.actorId,
    required this.department,
    required this.role,
    this.teamIds = const [],
    this.isSuperAdmin = false,
    this.isItManager = false,
  });

  final String actorId;
  final String department;
  final String role;
  final List<String> teamIds;
  final bool isSuperAdmin;
  final bool isItManager;

  bool can(
    WorkspaceCapability requested,
    String resourceId,
    Iterable<WorkspaceAccessGrant> grants,
  ) {
    if (isSuperAdmin || isItManager) return true;
    final matching = grants
        .where(
          (grant) =>
              grant.isActive &&
              grant.resourceId == resourceId &&
              _matches(grant) &&
              grant.capability.implies(requested),
        )
        .toList(growable: false);

    // A denial is intentionally evaluated first. This must stay deterministic
    // when a person inherits access from both department and team grants.
    if (matching.any((grant) => grant.effect == WorkspaceGrantEffect.deny)) {
      return false;
    }
    return matching.any((grant) => grant.effect == WorkspaceGrantEffect.allow);
  }

  bool _matches(WorkspaceAccessGrant grant) => switch (grant.scope) {
    WorkspaceGrantScope.employee ||
    WorkspaceGrantScope.resource => grant.subjectId == actorId,
    WorkspaceGrantScope.department => grant.subjectId == department,
    WorkspaceGrantScope.role => grant.subjectId == role,
    WorkspaceGrantScope.team => teamIds.contains(grant.subjectId),
  };
}
