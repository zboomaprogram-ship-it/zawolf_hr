import '../../../company_os/domain/entities/company_os_operation_receipt.dart';
import '../../../company_os/domain/entities/company_os_safe_error.dart';
import '../../../company_os/domain/entities/company_os_sync_state.dart';
import '../../domain/entities/organization_change_set.dart';
import '../../domain/entities/organization_membership.dart';
import '../../domain/entities/organization_snapshot.dart';
import '../../domain/entities/organization_unit.dart';
import '../../domain/entities/organization_tree.dart';
import '../../domain/entities/organization_tree_bootstrap.dart';
import '../../domain/repositories/multi_tree_organization_repository.dart';
import '../../domain/repositories/organization_structure_repository.dart';
import '../local/organization_structure_local_store.dart';
import '../remote/organization_structure_api.dart';

final class OrganizationStructureRepositoryImpl
    implements
        OrganizationStructureRepository,
        MultiTreeOrganizationRepository {
  OrganizationStructureRepositoryImpl({
    required OrganizationStructureApi api,
    OrganizationStructureLocalStore? local,
    this.actorUid,
    this.legacyFallback,
  }) : _api = api,
       _local = local;

  final OrganizationStructureApi _api;
  final OrganizationStructureLocalStore? _local;
  final Future<OrganizationSnapshot> Function()? legacyFallback;
  final String? actorUid;

  @override
  Future<OrganizationSnapshot> loadHierarchy({
    bool includeArchived = false,
  }) async {
    try {
      final rows = await _api.hierarchy(includeArchived: includeArchived);
      final snapshot = OrganizationSnapshot(
        units: rows.map(_unit).toList(growable: false),
        memberships: const [],
        version: rows.fold<int>(
          0,
          (value, row) => value + _int(row['version']),
        ),
        loadedAt: DateTime.now(),
      );
      await _local?.cache('legacy', snapshot);
      return snapshot;
    } catch (_) {
      final cached = await _local?.snapshot('legacy');
      if (cached != null) return cached;
      if (legacyFallback != null) return legacyFallback!();
      rethrow;
    }
  }

  @override
  Future<List<OrganizationMembership>> searchEmployees(String query) async =>
      (await _api.employees(query))
          .map(
            (row) => OrganizationMembership(
              employeeUid: _text(row['uid']),
              employeeName: _text(row['name']),
              employeeCode: _text(row['employeeId']),
              departmentUnitId: _optional(row['departmentUnitId']),
              directManagerUid: _optional(row['directManagerId']),
            ),
          )
          .toList(growable: false);

  @override
  Future<List<OrganizationTree>> loadTrees({
    bool includeArchived = false,
  }) async => (await _api.trees(
    includeArchived: includeArchived,
  )).map(_tree).toList(growable: false);

  @override
  Future<OrganizationSnapshot> loadTreeSnapshot(String treeId) async {
    try {
      return await _loadRemoteTreeSnapshot(treeId);
    } catch (_) {
      final cached = await _local?.snapshot('tree:$treeId');
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<OrganizationTreeBootstrapPreview> previewLegacyBootstrap() =>
      _api.bootstrapPreview();

  @override
  Future<void> applyLegacyBootstrap({
    required String operationId,
    required String approvedFingerprint,
  }) => _api.applyBootstrap(
    operationId: operationId,
    approvedFingerprint: approvedFingerprint,
  );

  Future<OrganizationSnapshot> _loadRemoteTreeSnapshot(String treeId) async {
    final data = await _api.treeSnapshot(treeId);
    final treeData = data['tree'];
    final rawUnits = data['units'];
    final rawMemberships = data['memberships'];
    if (treeData is! Map || rawUnits is! List || rawMemberships is! List) {
      throw const FormatException('Invalid organization tree snapshot');
    }
    final tree = _tree(Map<String, Object?>.from(treeData));
    final units = rawUnits
        .whereType<Map>()
        .map((row) => _unit(Map<String, Object?>.from(row)))
        .toList(growable: false);
    final memberships = rawMemberships
        .whereType<Map>()
        .map((row) {
          final value = Map<String, Object?>.from(row);
          return OrganizationMembership(
            id: _text(value['id']),
            treeId: _text(value['treeId']),
            employeeUid: _text(value['employeeUid']),
            employeeName: _text(value['employeeName']),
            employeeCode: _text(value['employeeCode']),
            departmentUnitId: _text(value['unitId']),
            directManagerUid: _optional(value['directManagerUid']),
            isPrimary: value['isPrimary'] == true,
            active: _text(value['status']) != 'archived',
            version: _int(value['version']),
          );
        })
        .toList(growable: false);
    final snapshot = OrganizationSnapshot(
      units: units,
      memberships: memberships,
      trees: [tree],
      selectedTreeId: tree.id,
      version: tree.version,
      loadedAt: DateTime.now(),
    );
    await _local?.cache('tree:$treeId', snapshot);
    return snapshot;
  }

  @override
  Future<OrganizationImpactPreview> preview(OrganizationChangeSet change) =>
      _api.preview(change);

  @override
  Future<CompanyOsOperationReceipt> apply(OrganizationChangeSet change) async {
    try {
      final receipt = await _api.apply(change);
      if (_local != null && actorUid != null) {
        await _local.reconcile(
          actorUid: actorUid!,
          operationId: change.operationId,
          state: receipt.status,
          safeCode: receipt.safeCode,
        );
      }
      return receipt;
    } on CompanyOsSafeError catch (error) {
      if (!error.retryable || _local == null || actorUid == null) rethrow;
      await _local.enqueue(
        actorUid: actorUid!,
        operationId: change.operationId,
        operationType: change.kind,
        targetId:
            _optional(change.payload['unitId']) ??
            _optional(change.payload['destinationDepartmentId']) ??
            _optional(change.payload['sourceDepartmentId']) ??
            'organization',
        payload: change.payload,
        expectedVersion: change.expectedVersion,
      );
      return CompanyOsOperationReceipt(
        operationId: change.operationId,
        status: CompanyOsSyncState.pending,
        safeCode: error.code.name,
      );
    }
  }

  @override
  Future<CompanyOsOperationReceipt?> operationStatus(String operationId) async {
    final receipt = await _api.status(operationId);
    if (receipt != null && _local != null && actorUid != null) {
      await _local.reconcile(
        actorUid: actorUid!,
        operationId: operationId,
        state: receipt.status,
        safeCode: receipt.safeCode,
      );
    }
    return receipt;
  }

  OrganizationUnit _unit(Map<String, Object?> row) => OrganizationUnit(
    id: _text(row['id']),
    treeId: _optional(row['treeId']) ?? 'default',
    type: _text(row['type']) == 'sector'
        ? OrganizationUnitType.sector
        : OrganizationUnitType.department,
    name: _text(row['name']),
    parentId: _optional(row['parentId']),
    managerUid: _optional(row['managerUid']),
    memberCount: _int(row['memberCount']),
    order: _int(row['order']),
    version: _int(row['version']),
    archived: row['archived'] == true,
  );

  OrganizationTree _tree(Map<String, Object?> row) => OrganizationTree(
    id: _text(row['id']),
    name: _text(row['name']),
    purpose: _optional(row['purpose']),
    rootLeaderUid: _optional(row['rootLeaderUid']),
    treeAdminUids: (row['treeAdminUids'] as List? ?? const [])
        .map((value) => '$value')
        .where((value) => value.isNotEmpty)
        .toList(growable: false),
    status: switch (_text(row['status'])) {
      'archived' => OrganizationTreeStatus.archived,
      'draft' => OrganizationTreeStatus.draft,
      _ => OrganizationTreeStatus.active,
    },
    version: _int(row['version']),
    isDefault: row['isDefault'] == true,
    order: _int(row['order']),
  );

  String _text(Object? value) => value?.toString() ?? '';
  String? _optional(Object? value) =>
      _text(value).trim().isEmpty ? null : _text(value);
  int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
}
