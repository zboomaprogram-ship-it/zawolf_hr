import '../entities/workspace_report.dart';

/// Read-only, privacy-safe audit history. The server remains responsible for
/// authorization and never returns cell values, formulas or provider tokens.
abstract interface class WorkspaceAuditRepository {
  Future<List<WorkspaceAuditEvent>> listEvents({
    required DateTime startsOn,
    required DateTime endsOn,
    int limit = 100,
  });
}
