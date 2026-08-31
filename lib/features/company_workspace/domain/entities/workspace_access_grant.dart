import 'workspace_capability.dart';

enum WorkspaceGrantScope { employee, team, department, role, resource }

/// A specific deny always wins over a broader allow.  This lets the company
/// remove access to one sensitive resource without changing an employee's
/// normal department or team access.
enum WorkspaceGrantEffect { allow, deny }

final class WorkspaceAccessGrant {
  const WorkspaceAccessGrant({
    required this.id,
    required this.resourceId,
    required this.scope,
    required this.subjectId,
    required this.capability,
    required this.isActive,
    required this.updatedAt,
    this.effect = WorkspaceGrantEffect.allow,
  });

  final String id;
  final String resourceId;
  final WorkspaceGrantScope scope;
  final String subjectId;
  final WorkspaceCapability capability;
  final bool isActive;
  final DateTime updatedAt;
  final WorkspaceGrantEffect effect;
}
