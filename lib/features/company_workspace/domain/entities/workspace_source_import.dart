final class WorkspaceSourceImportResult {
  const WorkspaceSourceImportResult({
    required this.discovered,
    required this.created,
    required this.updated,
    required this.grants,
  });

  final int discovered;
  final int created;
  final int updated;
  final int grants;
}
