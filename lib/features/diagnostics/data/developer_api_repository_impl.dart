import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/developer_api_client.dart';
import '../domain/repositories/developer_api_repository.dart';

final class DeveloperApiRepositoryImpl implements DeveloperApiRepository {
  DeveloperApiRepositoryImpl({
    required AuthenticatedOperationClient operationClient,
    required Uri baseUri,
  }) : _operationClient = operationClient,
       _baseUri = baseUri;

  final AuthenticatedOperationClient _operationClient;
  final Uri _baseUri;

  Uri get _clientsUri => _baseUri.resolve('/developer-api/v1/admin/clients');

  @override
  Future<List<DeveloperApiClient>> listClients() async {
    final response = await _operationClient.get(_clientsUri);
    if (!response.ok) throw DeveloperApiOperationException(response.safeCode);
    final raw = response.data['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(_clientFromWire).whereType<DeveloperApiClient>().toList(growable: false);
  }

  @override
  Future<IssuedDeveloperApiClient> createClient({
    required String name,
    required DateTime expiresAt,
    Set<String> scopes = const {'directory.read'},
  }) async {
    final response = await _operationClient.post(
      _clientsUri,
      operationId: 'developer-api-${DateTime.now().microsecondsSinceEpoch}',
      body: {
        'name': name.trim(),
        'scopes': scopes.toList(growable: false),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
    );
    if (!response.ok) throw DeveloperApiOperationException(response.safeCode);
    final client = response.data['client'];
    final secret = '${response.data['secret'] ?? ''}'.trim();
    final parsed = client is Map ? _clientFromWire(client) : null;
    if (parsed == null || secret.isEmpty) {
      throw const DeveloperApiOperationException('invalid_response');
    }
    return IssuedDeveloperApiClient(client: parsed, secret: secret);
  }

  @override
  Future<void> revokeClient({required String clientId, required String reason}) async {
    final response = await _operationClient.post(
      _baseUri.resolve('/developer-api/v1/admin/clients/$clientId/revoke'),
      operationId: 'developer-api-revoke-$clientId-${DateTime.now().microsecondsSinceEpoch}',
      body: {'reason': reason.trim()},
    );
    if (!response.ok) throw DeveloperApiOperationException(response.safeCode);
  }

  static DeveloperApiClient? _clientFromWire(Map raw) {
    final id = '${raw['id'] ?? ''}'.trim();
    final name = '${raw['name'] ?? ''}'.trim();
    final expiry = DateTime.tryParse('${raw['expiresAt'] ?? ''}');
    if (id.isEmpty || name.isEmpty || expiry == null) return null;
    return DeveloperApiClient(
      id: id,
      name: name,
      scopes: (raw['scopes'] as List? ?? const []).map((value) => '$value').toList(growable: false),
      status: '${raw['status'] ?? 'revoked'}',
      expiresAt: expiry,
      createdAt: DateTime.tryParse('${raw['createdAt'] ?? ''}'),
      revokedAt: DateTime.tryParse('${raw['revokedAt'] ?? ''}'),
    );
  }
}

final class DeveloperApiOperationException implements Exception {
  const DeveloperApiOperationException(this.code);
  final String code;
}
