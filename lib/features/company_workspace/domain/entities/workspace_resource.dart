import 'workspace_capability.dart';

enum WorkspaceResourceType { folder, spreadsheet, document, presentation, file }

final class WorkspaceResource {
  const WorkspaceResource({
    required this.id,
    required this.name,
    required this.type,
    required this.parentId,
    required this.version,
    required this.capabilities,
    this.modifiedAt,
  });

  final String id;
  final String name;
  final WorkspaceResourceType type;
  final String? parentId;
  final String version;
  final Set<WorkspaceCapability> capabilities;
  final DateTime? modifiedAt;

  bool can(WorkspaceCapability capability) =>
      capabilities.any((granted) => granted.implies(capability));
}

final class WorkspaceResourcePage {
  const WorkspaceResourcePage({required this.resources, this.nextPageToken});

  final List<WorkspaceResource> resources;
  final String? nextPageToken;
}

/// A provider-neutral binary returned only after the server has re-checked the
/// active ZaWolf grant for a resource. Provider IDs and direct Drive links are
/// deliberately absent.
final class WorkspaceDownloadedFile {
  const WorkspaceDownloadedFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}
