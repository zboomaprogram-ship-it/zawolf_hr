import '../entities/developer_api_client.dart';

abstract interface class DeveloperApiRepository {
  Future<List<DeveloperApiClient>> listClients();

  Future<IssuedDeveloperApiClient> createClient({
    required String name,
    required DateTime expiresAt,
    Set<String> scopes = const {'directory.read'},
  });

  Future<void> revokeClient({required String clientId, required String reason});
}
