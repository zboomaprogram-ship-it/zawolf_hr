import '../../../company_os/data/remote/company_os_api_client.dart';
import '../../../company_os/domain/entities/company_os_operation_receipt.dart';
import '../../../company_os/domain/entities/company_os_sync_state.dart';
import '../../domain/entities/organization_change_set.dart';
import '../../domain/entities/organization_tree_bootstrap.dart';

final class OrganizationStructureApi {
  const OrganizationStructureApi(this._client);
  final CompanyOsApiClient _client;

  Future<bool> multiTreeEnabled() async {
    final envelope = await _client.getEnvelope('/me');
    final flags = envelope['flags'];
    return flags is Map && flags['company_os_multi_tree_v1'] == true;
  }

  Future<bool> canManage() async {
    final envelope = await _client.getEnvelope('/me');
    final actor = envelope['actor'];
    if (actor is! Map) return false;
    final role = '${actor['role']}'.toLowerCase();
    final capabilities = <String>{
      ...?((actor['capabilities'] as List?)?.map((value) => '$value')),
      ...?((actor['operationalCapabilities'] as List?)?.map(
        (value) => '$value',
      )),
    };
    return capabilities.contains('organization_structure_manage') ||
        const {'hr', 'hr_admin', 'admin', 'super_admin'}.contains(role);
  }

  Future<List<Map<String, Object?>>> hierarchy({
    bool includeArchived = false,
  }) async => (await _client.list(
    '/organization/hierarchy',
    limit: 100,
    filters: {'includeArchived': '$includeArchived'},
  )).items;

  Future<List<Map<String, Object?>>> employees(String query) async =>
      (await _client.list(
        '/organization/employees',
        limit: 25,
        filters: {if (query.trim().isNotEmpty) 'query': query.trim()},
      )).items;

  Future<List<Map<String, Object?>>> trees({
    bool includeArchived = false,
  }) async => (await _client.list(
    '/organization/trees',
    limit: 25,
    filters: {'includeArchived': '$includeArchived'},
  )).items;

  Future<Map<String, Object?>> treeSnapshot(String treeId) => _client.getObject(
    '/organization/trees/$treeId/snapshot',
    filters: const {'limit': '100'},
  );

  Future<OrganizationTreeBootstrapPreview> bootstrapPreview() async {
    final data = await _client.getObject('/organization/bootstrap/preview');
    final summary = data['summary'] is Map
        ? Map<String, Object?>.from(data['summary'] as Map)
        : const <String, Object?>{};
    int value(String key) => summary[key] is int
        ? summary[key] as int
        : int.tryParse('${summary[key]}') ?? 0;
    return OrganizationTreeBootstrapPreview(
      fingerprint: '${data['fingerprint'] ?? ''}',
      trees: value('trees'),
      units: value('units'),
      memberships: value('memberships'),
      users: value('users'),
      legacyUnits: value('legacyUnits'),
      legacyIssues: value('legacyIssues'),
    );
  }

  Future<void> applyBootstrap({
    required String operationId,
    required String approvedFingerprint,
  }) async {
    await _client.postObject(
      '/organization/bootstrap/apply',
      operationId: operationId,
      payload: {'approvedFingerprint': approvedFingerprint},
    );
  }

  Future<OrganizationImpactPreview> preview(
    OrganizationChangeSet change,
  ) async {
    final result = await _client.postObject(
      '/organization/impact-preview',
      operationId: change.operationId,
      payload: {...change.payload, 'expectedVersion': change.expectedVersion},
    );
    return OrganizationImpactPreview(
      affectedEmployees: _int(result['affectedEmployees']),
      affectedDepartments: _int(result['affectedDepartments']),
    );
  }

  Future<CompanyOsOperationReceipt> apply(OrganizationChangeSet change) =>
      _client.mutate(
        _path(change),
        operationId: change.operationId,
        payload: {...change.payload, 'expectedVersion': change.expectedVersion},
      );

  Future<CompanyOsOperationReceipt?> status(String operationId) async {
    final result = await _client.getOptionalObject(
      '/organization/operations/$operationId',
    );
    if (result == null) return null;
    return CompanyOsOperationReceipt(
      operationId: result['operationId']?.toString() ?? operationId,
      status: switch ('${result['status']}') {
        'saved' || 'synced' => CompanyOsSyncState.synced,
        'pending' => CompanyOsSyncState.pending,
        'conflict' => CompanyOsSyncState.conflict,
        _ => CompanyOsSyncState.needsStatusCheck,
      },
      resourceId: result['resourceId']?.toString(),
      version: result['version'] is int
          ? result['version'] as int
          : int.tryParse('${result['version']}'),
      safeCode: result['safeCode']?.toString(),
    );
  }

  String _path(OrganizationChangeSet change) => switch (change.kind) {
    'create_unit' => '/organization/units',
    'rename_unit' => '/organization/units/${change.payload['unitId']}/rename',
    'move_unit' => '/organization/units/${change.payload['unitId']}/move',
    'archive_unit' => '/organization/units/${change.payload['unitId']}/archive',
    'restore_unit' => '/organization/units/${change.payload['unitId']}/restore',
    'assign_manager' =>
      '/organization/units/${change.payload['unitId']}/manager',
    'reorder' => '/organization/reorder',
    'membership' => '/organization/memberships',
    'create_tree' => '/organization/trees',
    'clone_tree' =>
      '/organization/trees/${change.payload['sourceTreeId']}/clone',
    'tree_membership' =>
      '/organization/trees/${change.payload['treeId']}/memberships',
    'primary_tree_membership' =>
      '/organization/tree-memberships/${change.payload['membershipId']}/primary',
    'archive_tree_membership' =>
      '/organization/tree-memberships/${change.payload['membershipId']}/archive',
    'archive_tree' => '/organization/trees/${change.payload['treeId']}/archive',
    'activate_tree' =>
      '/organization/trees/${change.payload['treeId']}/activate',
    'tree_leadership' =>
      '/organization/trees/${change.payload['treeId']}/leadership',
    _ => throw ArgumentError.value(change.kind, 'kind', 'unsupported'),
  };

  int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
}
