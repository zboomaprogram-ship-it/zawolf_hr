import '../entities/workspace_resource.dart';

abstract interface class WorkspaceResourceRepository {
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
  });

  Future<WorkspaceDownloadedFile> download(String resourceId);
}
