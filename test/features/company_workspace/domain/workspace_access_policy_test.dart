import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_policy.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20);
  WorkspaceAccessGrant grant({
    required WorkspaceGrantScope scope,
    required String subjectId,
    required WorkspaceCapability capability,
    WorkspaceGrantEffect effect = WorkspaceGrantEffect.allow,
    bool isActive = true,
  }) => WorkspaceAccessGrant(
    id: '$scope-$subjectId-$capability-$effect',
    resourceId: 'sensitive-sheet',
    scope: scope,
    subjectId: subjectId,
    capability: capability,
    effect: effect,
    isActive: isActive,
    updatedAt: now,
  );

  const policy = WorkspaceAccessPolicy(
    actorId: 'employee-1',
    department: 'Sales',
    role: 'employee',
    teamIds: ['team-a'],
  );

  test('department and team grants are inherited', () {
    final grants = [
      grant(
        scope: WorkspaceGrantScope.department,
        subjectId: 'Sales',
        capability: WorkspaceCapability.view,
      ),
      grant(
        scope: WorkspaceGrantScope.team,
        subjectId: 'team-a',
        capability: WorkspaceCapability.edit,
      ),
    ];

    expect(
      policy.can(WorkspaceCapability.view, 'sensitive-sheet', grants),
      isTrue,
    );
    expect(
      policy.can(WorkspaceCapability.edit, 'sensitive-sheet', grants),
      isTrue,
    );
  });

  test('resource-specific grant applies only to its named actor', () {
    final grants = [
      grant(
        scope: WorkspaceGrantScope.resource,
        subjectId: 'employee-1',
        capability: WorkspaceCapability.download,
      ),
    ];
    expect(
      policy.can(WorkspaceCapability.download, 'sensitive-sheet', grants),
      isTrue,
    );
  });

  test('revoked and stale grants do not create access', () {
    final grants = [
      grant(
        scope: WorkspaceGrantScope.employee,
        subjectId: 'employee-1',
        capability: WorkspaceCapability.edit,
        isActive: false,
      ),
    ];
    expect(
      policy.can(WorkspaceCapability.edit, 'sensitive-sheet', grants),
      isFalse,
    );
  });
}
