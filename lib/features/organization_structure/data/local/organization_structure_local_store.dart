import 'dart:convert';

import '../../../company_os/data/local/company_os_outbox.dart';
import '../../../company_os/data/local/company_os_database.dart';
import '../../../company_os/domain/entities/company_os_pending_operation.dart';
import '../../../company_os/domain/entities/company_os_sync_state.dart';
import '../../domain/entities/organization_snapshot.dart';
import '../../domain/entities/organization_membership.dart';
import '../../domain/entities/organization_tree.dart';
import '../../domain/entities/organization_unit.dart';

/// The durable write queue delegates to the shared Drift-backed Company OS
/// outbox. The last safe snapshot remains an in-process fallback; the legacy
/// organization service is retained as the cold-start fallback until rollout.
final class OrganizationStructureLocalStore {
  OrganizationStructureLocalStore({
    required CompanyOsOutbox outbox,
    required CompanyOsDatabase database,
  }) : _outbox = outbox,
       _database = database;
  final CompanyOsOutbox _outbox;
  final CompanyOsDatabase _database;

  Future<OrganizationSnapshot?> snapshot(String cacheKey) async {
    final row =
        await (_database.select(_database.companyOsSnapshotRows)
              ..where((row) => row.cacheKey.equals(cacheKey))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.payloadJson);
      return decoded is Map<String, dynamic>
          ? _decode(decoded, row.loadedAt)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> cache(String cacheKey, OrganizationSnapshot value) => _database
      .into(_database.companyOsSnapshotRows)
      .insertOnConflictUpdate(
        CompanyOsSnapshotRowsCompanion.insert(
          cacheKey: cacheKey,
          payloadJson: jsonEncode(_encode(value)),
          loadedAt: value.loadedAt.toUtc(),
        ),
      );

  Future<void> enqueue({
    required String actorUid,
    required String operationId,
    required String operationType,
    required String targetId,
    required Map<String, Object?> payload,
    int? expectedVersion,
  }) => _outbox.put(
    CompanyOsPendingOperation(
      operationId: operationId,
      actorUid: actorUid,
      operationType: operationType,
      targetId: targetId,
      payload: payload,
      expectedVersion: expectedVersion,
      state: CompanyOsSyncState.pending,
      attemptCount: 0,
      nextAttemptAt: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
    ),
  );

  Future<void> reconcile({
    required String actorUid,
    required String operationId,
    required CompanyOsSyncState state,
    String? safeCode,
  }) => _outbox.reconcile(
    operationId: operationId,
    actorUid: actorUid,
    state: state,
    lastSafeCode: safeCode,
  );

  Map<String, Object?> _encode(OrganizationSnapshot value) => {
    'version': value.version,
    'selectedTreeId': value.selectedTreeId,
    'units': [
      for (final unit in value.units)
        {
          'id': unit.id,
          'treeId': unit.treeId,
          'type': unit.type.name,
          'name': unit.name,
          'parentId': unit.parentId,
          'managerUid': unit.managerUid,
          'memberCount': unit.memberCount,
          'order': unit.order,
          'version': unit.version,
          'archived': unit.archived,
        },
    ],
    'memberships': [
      for (final membership in value.memberships)
        {
          'id': membership.id,
          'treeId': membership.treeId,
          'employeeUid': membership.employeeUid,
          'employeeName': membership.employeeName,
          'employeeCode': membership.employeeCode,
          'departmentUnitId': membership.departmentUnitId,
          'directManagerUid': membership.directManagerUid,
          'active': membership.active,
          'isPrimary': membership.isPrimary,
          'version': membership.version,
        },
    ],
    'trees': [
      for (final tree in value.trees)
        {
          'id': tree.id,
          'name': tree.name,
          'purpose': tree.purpose,
          'rootLeaderUid': tree.rootLeaderUid,
          'treeAdminUids': tree.treeAdminUids,
          'status': tree.status.name,
          'version': tree.version,
          'isDefault': tree.isDefault,
          'order': tree.order,
        },
    ],
  };

  OrganizationSnapshot _decode(Map<String, dynamic> value, DateTime loadedAt) {
    final units = (value['units'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return OrganizationUnit(
            id: '${item['id'] ?? ''}',
            treeId: '${item['treeId'] ?? 'default'}',
            type: item['type'] == 'sector'
                ? OrganizationUnitType.sector
                : OrganizationUnitType.department,
            name: '${item['name'] ?? ''}',
            parentId: item['parentId']?.toString(),
            managerUid: item['managerUid']?.toString(),
            memberCount: (item['memberCount'] as num?)?.toInt() ?? 0,
            order: (item['order'] as num?)?.toInt() ?? 0,
            version: (item['version'] as num?)?.toInt() ?? 0,
            archived: item['archived'] == true,
          );
        })
        .toList(growable: false);
    final memberships = (value['memberships'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return OrganizationMembership(
            id: item['id']?.toString(),
            treeId: '${item['treeId'] ?? 'default'}',
            employeeUid: '${item['employeeUid'] ?? ''}',
            employeeName: '${item['employeeName'] ?? ''}',
            employeeCode: '${item['employeeCode'] ?? ''}',
            departmentUnitId: item['departmentUnitId']?.toString(),
            directManagerUid: item['directManagerUid']?.toString(),
            active: item['active'] != false,
            isPrimary: item['isPrimary'] == true,
            version: item['version'] is int
                ? item['version'] as int
                : int.tryParse('${item['version']}') ?? 1,
          );
        })
        .toList(growable: false);
    final trees = (value['trees'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return OrganizationTree(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? ''}',
            purpose: item['purpose']?.toString(),
            rootLeaderUid: item['rootLeaderUid']?.toString(),
            treeAdminUids: (item['treeAdminUids'] as List? ?? const [])
                .map((value) => '$value')
                .toList(growable: false),
            status: OrganizationTreeStatus.values.firstWhere(
              (status) => status.name == item['status'],
              orElse: () => OrganizationTreeStatus.draft,
            ),
            version: (item['version'] as num?)?.toInt() ?? 0,
            isDefault: item['isDefault'] == true,
            order: (item['order'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);
    return OrganizationSnapshot(
      units: units,
      memberships: memberships,
      trees: trees,
      selectedTreeId: value['selectedTreeId']?.toString(),
      version: (value['version'] as num?)?.toInt() ?? 0,
      loadedAt: loadedAt.toLocal(),
    );
  }
}
