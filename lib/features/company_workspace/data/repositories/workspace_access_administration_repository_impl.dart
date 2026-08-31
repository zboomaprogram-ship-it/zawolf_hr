import '../../domain/entities/workspace_access_grant.dart';
import '../../domain/entities/workspace_capability.dart';
import '../../domain/entities/workspace_source_import.dart';
import '../../domain/entities/workspace_pilot_configuration.dart';
import '../../domain/repositories/workspace_access_administration_repository.dart';
import '../datasources/workspace_access_admin_remote_data_source.dart';

final class WorkspaceAccessAdministrationRepositoryImpl
    implements WorkspaceAccessAdministrationRepository {
  const WorkspaceAccessAdministrationRepositoryImpl(this._remote);

  final WorkspaceAccessAdminRemoteDataSource _remote;

  @override
  Future<String> createGrant(WorkspaceAccessGrant grant) =>
      _remote.createGrant({
        'resourceId': grant.resourceId,
        'scope': grant.scope.name,
        'subjectId': grant.subjectId,
        'capability': grant.capability.name,
        'effect': grant.effect.name,
      });

  @override
  Future<List<WorkspaceAccessGrant>> listGrants(String resourceId) async =>
      (await _remote.listGrants(
        resourceId,
      )).map(_grantFromJson).toList(growable: false);

  @override
  Future<void> revokeGrant(String grantId) => _remote.revokeGrant(grantId);

  @override
  Future<WorkspaceSourceImportResult> importCompanySource() async {
    final result = await _remote.importCompanySource();
    int number(String key) => (result[key] as num?)?.toInt() ?? 0;
    return WorkspaceSourceImportResult(
      discovered: number('discovered'),
      created: number('created'),
      updated: number('updated'),
      grants: number('grants'),
    );
  }

  @override
  Future<WorkspacePilotConfiguration> loadPilotConfiguration() async {
    final result = await _remote.loadPilotConfiguration();
    final raw = result['configuration'];
    final configuration = raw is Map ? Map<String, Object?>.from(raw) : result;
    final ids = configuration['enabledActorIds'];
    final updatedAt = configuration['updatedAt'];
    return WorkspacePilotConfiguration(
      enabledForEveryone: configuration['enabledForEveryone'] == true,
      enabledActorIds: ids is List
          ? ids.map((value) => value.toString()).toList(growable: false)
          : const [],
      updatedAt: updatedAt is String
          ? DateTime.tryParse(updatedAt)?.toUtc()
          : null,
    );
  }

  @override
  Future<void> savePilotConfiguration(
    WorkspacePilotConfiguration configuration, {
    required String reason,
  }) => _remote.savePilotConfiguration({
    'enabledForEveryone': configuration.enabledForEveryone,
    'enabledActorIds': configuration.enabledActorIds,
    'reason': reason,
  });

  WorkspaceAccessGrant _grantFromJson(Map<String, Object?> json) {
    T enumValue<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    final updatedRaw = json['updatedAt'];
    final updatedAt = updatedRaw is String
        ? DateTime.tryParse(updatedRaw)?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return WorkspaceAccessGrant(
      id: (json['id'] ?? '').toString(),
      resourceId: (json['resourceId'] ?? '').toString(),
      scope: enumValue(
        WorkspaceGrantScope.values,
        json['scope'],
        WorkspaceGrantScope.employee,
      ),
      subjectId: (json['subjectId'] ?? json['userId'] ?? '').toString(),
      capability: enumValue(
        WorkspaceCapability.values,
        json['capability'] ?? json['permission'],
        WorkspaceCapability.view,
      ),
      effect: enumValue(
        WorkspaceGrantEffect.values,
        json['effect'],
        WorkspaceGrantEffect.allow,
      ),
      isActive: json['isActive'] == true,
      updatedAt: updatedAt,
    );
  }
}
