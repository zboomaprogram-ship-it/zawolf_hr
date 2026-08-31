final class OperationalAuditEvent {
  OperationalAuditEvent({
    required this.id,
    required this.operationId,
    required this.actorUid,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    required Map<String, Object?> safeBefore,
    required Map<String, Object?> safeAfter,
    required this.createdAt,
  }) : safeBefore = Map.unmodifiable(safeBefore),
       safeAfter = Map.unmodifiable(safeAfter);

  final String id;
  final String operationId;
  final String actorUid;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, Object?> safeBefore;
  final Map<String, Object?> safeAfter;
  final DateTime createdAt;
}
