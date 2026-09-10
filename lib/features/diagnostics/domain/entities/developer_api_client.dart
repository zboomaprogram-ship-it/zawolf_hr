final class DeveloperApiClient {
  const DeveloperApiClient({
    required this.id,
    required this.name,
    required this.scopes,
    required this.status,
    required this.expiresAt,
    this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final List<String> scopes;
  final String status;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());
}

final class IssuedDeveloperApiClient {
  const IssuedDeveloperApiClient({required this.client, required this.secret});
  final DeveloperApiClient client;

  /// Available exactly once after creation. It must never be persisted.
  final String secret;
}
