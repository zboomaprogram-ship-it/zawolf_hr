import '../entities/workspace_access_grant.dart';
import '../entities/workspace_source_import.dart';
import '../entities/workspace_pilot_configuration.dart';

abstract interface class WorkspaceAccessAdministrationRepository {
  Future<List<WorkspaceAccessGrant>> listGrants(String resourceId);

  Future<String> createGrant(WorkspaceAccessGrant grant);

  Future<void> revokeGrant(String grantId);

  Future<WorkspaceSourceImportResult> importCompanySource();

  Future<WorkspacePilotConfiguration> loadPilotConfiguration();

  Future<void> savePilotConfiguration(
    WorkspacePilotConfiguration configuration, {
    required String reason,
  });
}
