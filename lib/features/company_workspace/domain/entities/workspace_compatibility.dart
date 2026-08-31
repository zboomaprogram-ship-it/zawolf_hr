enum WorkspaceCompatibility {
  editable,
  readOnly,
  unsupported,
  migrationRequired,
}

final class WorkspaceCapabilityProfile {
  const WorkspaceCapabilityProfile({
    required this.id,
    required this.compatibility,
    this.reason,
  });

  final String id;
  final WorkspaceCompatibility compatibility;
  final String? reason;

  bool get canMutate => compatibility == WorkspaceCompatibility.editable;
}
