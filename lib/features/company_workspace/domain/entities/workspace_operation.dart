enum WorkspaceOperationKind {
  resourceList,
  fileCreate,
  fileUpload,
  fileDownload,
  fileRename,
  fileMove,
  fileCopy,
  fileTrash,
  fileRestore,
  sheetRead,
  sheetEdit,
  sheetPaste,
  sheetFormat,
  sheetStructure,
  sheetTab,
  accessChange,
  reportGenerate,
}

enum WorkspaceOperationState { pending, acknowledged, rejected, conflict }

final class WorkspaceOperation {
  const WorkspaceOperation({
    required this.id,
    required this.actorId,
    required this.resourceId,
    required this.kind,
    required this.createdAt,
    this.expectedVersion,
    this.payload = const <String, Object?>{},
    this.state = WorkspaceOperationState.pending,
    this.safeMessage,
  });

  final String id;
  final String actorId;
  final String resourceId;
  final WorkspaceOperationKind kind;
  final DateTime createdAt;
  final String? expectedVersion;
  /// Operation-specific, provider-neutral values such as a display name or a
  /// bounded sheet range.  Never place tokens, URLs containing credentials,
  /// or provider exception strings here.
  final Map<String, Object?> payload;
  final WorkspaceOperationState state;
  final String? safeMessage;

  WorkspaceOperation acknowledge({String? safeMessage}) => WorkspaceOperation(
    id: id,
    actorId: actorId,
    resourceId: resourceId,
    kind: kind,
    createdAt: createdAt,
    expectedVersion: expectedVersion,
    payload: payload,
    state: WorkspaceOperationState.acknowledged,
    safeMessage: safeMessage,
  );

  WorkspaceOperation reject(String safeMessage) => WorkspaceOperation(
    id: id,
    actorId: actorId,
    resourceId: resourceId,
    kind: kind,
    createdAt: createdAt,
    expectedVersion: expectedVersion,
    payload: payload,
    state: WorkspaceOperationState.rejected,
    safeMessage: safeMessage,
  );

  WorkspaceOperation conflict(String safeMessage) => WorkspaceOperation(
    id: id,
    actorId: actorId,
    resourceId: resourceId,
    kind: kind,
    createdAt: createdAt,
    expectedVersion: expectedVersion,
    payload: payload,
    state: WorkspaceOperationState.conflict,
    safeMessage: safeMessage,
  );
}
