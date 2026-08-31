import '../../domain/entities/workspace_audit_action.dart';
import '../../domain/entities/workspace_report.dart';

final class WorkspaceAuditEventDto {
  const WorkspaceAuditEventDto({
    required this.id,
    required this.actorId,
    required this.resourceId,
    required this.action,
    required this.occurredAt,
    required this.changeCount,
    this.range,
  });

  final String id;
  final String actorId;
  final String resourceId;
  final WorkspaceAuditAction action;
  final DateTime occurredAt;
  final int changeCount;
  final String? range;

  factory WorkspaceAuditEventDto.fromJson(Map<String, Object?> json) {
    final action =
        _actions[json['action']?.toString() ?? ''] ??
        WorkspaceAuditAction.externalActivityDetected;
    return WorkspaceAuditEventDto(
      id: json['id']?.toString() ?? '',
      actorId: json['actorId']?.toString() ?? 'external_unattributed',
      resourceId: json['resourceId']?.toString() ?? '',
      action: action,
      occurredAt:
          DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      changeCount: (json['changeCount'] as num?)?.toInt() ?? 0,
      range: json['range'] as String?,
    );
  }

  WorkspaceAuditEvent toDomain() => WorkspaceAuditEvent(
    id: id,
    actorId: actorId,
    resourceId: resourceId,
    action: action,
    occurredAt: occurredAt,
    changeCount: changeCount,
    range: range,
  );
}

const _actions = <String, WorkspaceAuditAction>{
  'resource_open': WorkspaceAuditAction.resourceViewed,
  'resource_list': WorkspaceAuditAction.resourceSearched,
  'file_download': WorkspaceAuditAction.resourceDownloaded,
  'file_upload': WorkspaceAuditAction.fileUploaded,
  'file_create': WorkspaceAuditAction.fileCreated,
  'file_rename': WorkspaceAuditAction.fileRenamed,
  'file_move': WorkspaceAuditAction.fileMoved,
  'file_copy': WorkspaceAuditAction.fileCopied,
  'file_trash': WorkspaceAuditAction.fileTrashed,
  'file_restore': WorkspaceAuditAction.fileRestored,
  'sheet_edit': WorkspaceAuditAction.sheetEdited,
  'sheet_paste': WorkspaceAuditAction.sheetPasted,
  'sheet_format': WorkspaceAuditAction.sheetFormatted,
  'sheet_structure': WorkspaceAuditAction.sheetStructureChanged,
  'sheet_tab': WorkspaceAuditAction.sheetTabChanged,
  'access_change': WorkspaceAuditAction.accessGranted,
  'report_generate': WorkspaceAuditAction.reportGenerated,
  'external_activity': WorkspaceAuditAction.externalActivityDetected,
};
