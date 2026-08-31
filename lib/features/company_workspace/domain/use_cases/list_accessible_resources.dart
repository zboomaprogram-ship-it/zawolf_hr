import '../entities/workspace_resource.dart';
import '../repositories/workspace_resource_repository.dart';

final class ListAccessibleResources {
  const ListAccessibleResources(this._repository);

  final WorkspaceResourceRepository _repository;

  Future<WorkspaceResourcePage> call({
    required String? parentId,
    String? pageToken,
  }) => _repository.listAccessible(parentId: parentId, pageToken: pageToken);
}
