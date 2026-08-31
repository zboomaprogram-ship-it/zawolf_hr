import '../entities/workspace_access_grant.dart';
import '../entities/workspace_source_import.dart';
import '../repositories/workspace_access_administration_repository.dart';

/// Small application use-cases keep access administration intent in the
/// domain layer.  Transport, authorization and Google provider details remain
/// behind [WorkspaceAccessAdministrationRepository].
final class ListWorkspaceAccessGrants {
  const ListWorkspaceAccessGrants(this._repository);

  final WorkspaceAccessAdministrationRepository _repository;

  Future<List<WorkspaceAccessGrant>> call(String resourceId) =>
      _repository.listGrants(resourceId);
}

final class GrantWorkspaceAccess {
  const GrantWorkspaceAccess(this._repository);

  final WorkspaceAccessAdministrationRepository _repository;

  Future<String> call(WorkspaceAccessGrant grant) =>
      _repository.createGrant(grant);
}

final class RevokeWorkspaceAccess {
  const RevokeWorkspaceAccess(this._repository);

  final WorkspaceAccessAdministrationRepository _repository;

  Future<void> call(String grantId) => _repository.revokeGrant(grantId);
}

final class ImportCompanyWorkspaceSource {
  const ImportCompanyWorkspaceSource(this._repository);

  final WorkspaceAccessAdministrationRepository _repository;

  Future<WorkspaceSourceImportResult> call() =>
      _repository.importCompanySource();
}
