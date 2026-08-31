import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_policy.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_operation.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_report_period.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20);

  WorkspaceAccessGrant grant({
    required WorkspaceGrantScope scope,
    required String subjectId,
    required WorkspaceCapability capability,
    bool active = true,
    WorkspaceGrantEffect effect = WorkspaceGrantEffect.allow,
  }) => WorkspaceAccessGrant(
    id: '$scope-$subjectId',
    resourceId: 'resource-1',
    scope: scope,
    subjectId: subjectId,
    capability: capability,
    isActive: active,
    updatedAt: now,
    effect: effect,
  );

  test('edit access includes normal view, download and comment actions', () {
    const policy = WorkspaceAccessPolicy(
      actorId: 'employee-1',
      department: 'Sales',
      role: 'employee',
    );
    final grants = [
      grant(
        scope: WorkspaceGrantScope.employee,
        subjectId: 'employee-1',
        capability: WorkspaceCapability.edit,
      ),
    ];

    expect(policy.can(WorkspaceCapability.view, 'resource-1', grants), isTrue);
    expect(
      policy.can(WorkspaceCapability.download, 'resource-1', grants),
      isTrue,
    );
    expect(
      policy.can(WorkspaceCapability.comment, 'resource-1', grants),
      isTrue,
    );
    expect(policy.can(WorkspaceCapability.edit, 'resource-1', grants), isTrue);
    expect(
      policy.can(WorkspaceCapability.manageContent, 'resource-1', grants),
      isFalse,
    );
  });

  test('revoked grants never provide access', () {
    const policy = WorkspaceAccessPolicy(
      actorId: 'employee-1',
      department: 'Sales',
      role: 'employee',
    );
    final grants = [
      grant(
        scope: WorkspaceGrantScope.employee,
        subjectId: 'employee-1',
        capability: WorkspaceCapability.edit,
        active: false,
      ),
    ];

    expect(policy.can(WorkspaceCapability.view, 'resource-1', grants), isFalse);
  });

  test('an explicit matching deny overrides inherited access', () {
    const policy = WorkspaceAccessPolicy(
      actorId: 'employee-1',
      department: 'Sales',
      role: 'employee',
    );
    final grants = [
      grant(
        scope: WorkspaceGrantScope.department,
        subjectId: 'Sales',
        capability: WorkspaceCapability.edit,
      ),
      grant(
        scope: WorkspaceGrantScope.employee,
        subjectId: 'employee-1',
        capability: WorkspaceCapability.view,
        effect: WorkspaceGrantEffect.deny,
      ),
    ];

    expect(policy.can(WorkspaceCapability.view, 'resource-1', grants), isFalse);
    expect(policy.can(WorkspaceCapability.edit, 'resource-1', grants), isTrue);
  });

  test('current IT manager is a controller without a fixed employee code', () {
    const policy = WorkspaceAccessPolicy(
      actorId: 'any-current-it-manager',
      department: 'IT',
      role: 'manager',
      isItManager: true,
    );

    expect(
      policy.can(WorkspaceCapability.manageAccess, 'any-resource', const []),
      isTrue,
    );
  });

  test('workspace operation has explicit terminal states', () {
    final operation = WorkspaceOperation(
      id: 'op-1',
      actorId: 'employee-1',
      resourceId: 'resource-1',
      kind: WorkspaceOperationKind.sheetEdit,
      createdAt: now,
      expectedVersion: 'v1',
    );

    expect(operation.acknowledge().state, WorkspaceOperationState.acknowledged);
    expect(
      operation.reject('تعذر الحفظ.').state,
      WorkspaceOperationState.rejected,
    );
    expect(
      operation.conflict('تم تعديل الملف.').state,
      WorkspaceOperationState.conflict,
    );
  });

  test('report key is stable for an identical business period and scope', () {
    final period = WorkspaceReportPeriod(
      type: WorkspaceReportPeriodType.monthly,
      startsOn: DateTime.utc(2026, 8, 1),
      endsOn: DateTime.utc(2026, 8, 31),
    );

    expect(
      period.reportKey(reportType: 'hr_attendance', scopeId: 'hr'),
      'hr_attendance:hr:monthly:2026-08-01:2026-08-31',
    );
  });
}
