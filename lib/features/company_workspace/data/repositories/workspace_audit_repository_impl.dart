import '../../domain/entities/workspace_report.dart';
import '../../domain/repositories/workspace_audit_repository.dart';
import '../datasources/workspace_audit_remote_data_source.dart';

final class WorkspaceAuditRepositoryImpl implements WorkspaceAuditRepository {
  const WorkspaceAuditRepositoryImpl(this._remote);
  final WorkspaceAuditRemoteDataSource _remote;

  @override
  Future<List<WorkspaceAuditEvent>> listEvents({
    required DateTime startsOn,
    required DateTime endsOn,
    int limit = 100,
  }) async => (await _remote.listEvents(
    startsOn: startsOn,
    endsOn: endsOn,
    limit: limit,
  )).map((event) => event.toDomain()).toList(growable: false);
}
