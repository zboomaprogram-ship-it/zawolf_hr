import 'workspace_audit_action.dart';

final class WorkspaceAuditEvent {
  const WorkspaceAuditEvent({
    required this.id,
    required this.actorId,
    required this.resourceId,
    required this.action,
    required this.occurredAt,
    this.changeCount = 0,
    this.range,
  });

  final String id;
  final String actorId;
  final String resourceId;
  final WorkspaceAuditAction action;
  final DateTime occurredAt;
  final int changeCount;
  final String? range;
}

enum WorkspaceReportState { generating, ready, failedRetryable }

final class WorkspaceReportRun {
  const WorkspaceReportRun({
    required this.id,
    required this.key,
    required this.state,
    this.resourceId,
  });

  final String id;
  final String key;
  final WorkspaceReportState state;
  final String? resourceId;
}
