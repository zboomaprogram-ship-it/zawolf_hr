import '../../domain/entities/workspace_resource.dart';
import '../../domain/repositories/workspace_resource_repository.dart';
import '../datasources/workspace_resource_remote_data_source.dart';

final class WorkspaceResourceRepositoryImpl
    implements WorkspaceResourceRepository {
  const WorkspaceResourceRepositoryImpl(this._remote);
  final WorkspaceResourceRemoteDataSource _remote;

  @override
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
  }) => _remote.listAccessible(parentId: parentId, pageToken: pageToken);

  @override
  Future<WorkspaceDownloadedFile> download(String resourceId) =>
      _remote.download(resourceId);
}
