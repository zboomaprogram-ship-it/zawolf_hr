import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/developer_tools_entitlement.dart';
import '../domain/repositories/developer_tools_repository.dart';

final class DeveloperToolsRepositoryImpl implements DeveloperToolsRepository {
  DeveloperToolsRepositoryImpl({
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
  }) : _operationClient = operationClient,
       _operationsBaseUri = operationsBaseUri;

  final AuthenticatedOperationClient _operationClient;
  final Uri _operationsBaseUri;

  @override
  Future<DeveloperToolsEntitlement?> loadMyEntitlement() async {
    final response = await _operationClient.get(
      _operationsBaseUri.resolve('/operations/developer-tools/me'),
    );
    if (!response.ok || response.data['enabled'] != true) return null;
    final raw = response.data['entitlement'];
    if (raw is! Map) return null;
    final permanent = raw['permanent'] == true;
    final expiry = DateTime.tryParse((raw['expiresAt'] ?? '').toString());
    if (!permanent && expiry == null) return null;
    return DeveloperToolsEntitlement(
      employeeUserId: '',
      scopes: _scopes(raw['scopes']),
      expiresAt: expiry,
      permanent: permanent,
      grantedByUserId: '',
    );
  }

  @override
  Future<void> grant({
    required String employeeUserId,
    required Set<DeveloperToolScope> scopes,
    DateTime? expiresAt,
    bool permanent = false,
  }) async {
    // No expiry is a permanent, restricted developer-tools grant. Keep the
    // wire contract explicit so legacy pages cannot accidentally send an
    // invalid "temporary without expiry" request.
    final expiry = expiresAt;
    final isPermanent = permanent || expiry == null;
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/operations/developer-tools/entitlements'),
      operationId:
          'devtools-$employeeUserId-${isPermanent ? 'permanent' : expiry.microsecondsSinceEpoch}',
      body: {
        'employeeUserId': employeeUserId,
        'scopes': scopes.map(_scopeWireValue).toList(growable: false),
        if (!isPermanent) 'expiresAt': expiry.toUtc().toIso8601String(),
        'permanent': isPermanent,
      },
    );
    if (!response.ok) {
      throw DeveloperToolsOperationException(response.safeCode);
    }
  }

  @override
  Future<void> revoke(String employeeUserId) async {
    final response = await _operationClient.delete(
      _operationsBaseUri.resolve(
        '/operations/developer-tools/entitlements/$employeeUserId',
      ),
    );
    if (!response.ok) {
      throw DeveloperToolsOperationException(response.safeCode);
    }
  }

  static Set<DeveloperToolScope> _scopes(Object? raw) {
    if (raw is! List) return const {};
    return raw
        .map(
          (item) => switch ('$item') {
            'app_diagnostics' => DeveloperToolScope.appDiagnostics,
            'network_diagnostics' => DeveloperToolScope.networkDiagnostics,
            'release_information' => DeveloperToolScope.releaseInformation,
            _ => null,
          },
        )
        .whereType<DeveloperToolScope>()
        .toSet();
  }

  static String _scopeWireValue(DeveloperToolScope scope) => switch (scope) {
    DeveloperToolScope.appDiagnostics => 'app_diagnostics',
    DeveloperToolScope.networkDiagnostics => 'network_diagnostics',
    DeveloperToolScope.releaseInformation => 'release_information',
  };
}

final class DeveloperToolsOperationException implements Exception {
  const DeveloperToolsOperationException(this.safeCode);

  final String safeCode;
}
