enum OperationalRole {
  employee,
  itSupport,
  itManager,
  finance,
  manager,
  admin,
  superAdmin,
}

enum OperationalScopeType { self, team, department, company }

final class OperationalRoleGrant {
  const OperationalRoleGrant({
    required this.id,
    required this.employeeUid,
    required this.role,
    required this.scopeType,
    required this.active,
    required this.startsAt,
    this.scopeIds = const <String>[],
    this.expiresAt,
  });

  final String id;
  final String employeeUid;
  final OperationalRole role;
  final OperationalScopeType scopeType;
  final List<String> scopeIds;
  final bool active;
  final DateTime startsAt;
  final DateTime? expiresAt;

  bool isEffectiveAt(DateTime instant) =>
      active &&
      !instant.isBefore(startsAt) &&
      (expiresAt == null || instant.isBefore(expiresAt!));
}
