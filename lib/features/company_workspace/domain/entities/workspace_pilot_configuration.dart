/// Server-owned rollout state for the reversible Workspace V2 pilot.
///
/// Actor IDs are Firebase UIDs, never employee codes, so a role or code change
/// cannot accidentally grant a pilot route.
final class WorkspacePilotConfiguration {
  const WorkspacePilotConfiguration({
    required this.enabledForEveryone,
    required this.enabledActorIds,
    this.updatedAt,
  });

  final bool enabledForEveryone;
  final List<String> enabledActorIds;
  final DateTime? updatedAt;
}
