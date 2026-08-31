import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_access_grant.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_capability.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_source_import.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_pilot_configuration.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/workspace_access_administration_repository.dart';
import 'package:zawolf_hr/features/company_workspace/domain/use_cases/manage_workspace_access.dart';

void main() {
  test(
    'access use-cases delegate without knowing persistence details',
    () async {
      final repository = _Repository();
      final grant = WorkspaceAccessGrant(
        id: 'grant-1',
        resourceId: 'resource-1',
        scope: WorkspaceGrantScope.employee,
        subjectId: 'employee-1',
        capability: WorkspaceCapability.edit,
        isActive: true,
        updatedAt: DateTime.utc(2026, 8, 22),
      );

      expect(await GrantWorkspaceAccess(repository)(grant), 'grant-1');
      expect(await ListWorkspaceAccessGrants(repository)('resource-1'), [
        grant,
      ]);
      await RevokeWorkspaceAccess(repository)('grant-1');
      expect(repository.revokedGrantId, 'grant-1');
      expect((await ImportCompanyWorkspaceSource(repository)()).discovered, 4);
    },
  );
}

final class _Repository implements WorkspaceAccessAdministrationRepository {
  WorkspaceAccessGrant? created;
  String? revokedGrantId;

  @override
  Future<String> createGrant(WorkspaceAccessGrant grant) async {
    created = grant;
    return grant.id;
  }

  @override
  Future<WorkspaceSourceImportResult> importCompanySource() async =>
      const WorkspaceSourceImportResult(
        discovered: 4,
        created: 2,
        updated: 2,
        grants: 0,
      );

  @override
  Future<List<WorkspaceAccessGrant>> listGrants(String resourceId) async =>
      created == null ? const [] : [created!];

  @override
  Future<void> revokeGrant(String grantId) async => revokedGrantId = grantId;

  @override
  Future<WorkspacePilotConfiguration> loadPilotConfiguration() async =>
      const WorkspacePilotConfiguration(
        enabledForEveryone: false,
        enabledActorIds: [],
      );

  @override
  Future<void> savePilotConfiguration(
    WorkspacePilotConfiguration configuration, {
    required String reason,
  }) async {}
}
