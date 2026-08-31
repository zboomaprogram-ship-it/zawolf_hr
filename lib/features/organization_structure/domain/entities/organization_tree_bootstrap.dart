/// A preview-first, additive migration from the legacy organisation records
/// into the currently selected organisation-tree store.
final class OrganizationTreeBootstrapPreview {
  const OrganizationTreeBootstrapPreview({
    required this.fingerprint,
    required this.trees,
    required this.units,
    required this.memberships,
    required this.users,
    required this.legacyUnits,
    required this.legacyIssues,
  });

  final String fingerprint;
  final int trees;
  final int units;
  final int memberships;
  final int users;
  final int legacyUnits;
  final int legacyIssues;

  bool get hasChanges => trees + units + memberships + users + legacyUnits > 0;
}
