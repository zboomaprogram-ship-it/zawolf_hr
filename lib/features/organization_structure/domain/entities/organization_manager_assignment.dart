final class OrganizationManagerAssignment {
  const OrganizationManagerAssignment({
    required this.id,
    required this.unitId,
    required this.managerUid,
    required this.startedAt,
    required this.assignedBy,
    this.endedAt,
  });

  final String id;
  final String unitId;
  final String managerUid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String assignedBy;

  bool get isActive => endedAt == null;
}
