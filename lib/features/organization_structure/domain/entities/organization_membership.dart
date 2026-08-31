final class OrganizationMembership {
  const OrganizationMembership({
    required this.employeeUid,
    required this.employeeName,
    required this.employeeCode,
    this.id,
    this.treeId = 'default',
    this.isPrimary = true,
    this.departmentUnitId,
    this.directManagerUid,
    this.active = true,
    this.version = 1,
  });

  final String employeeUid;
  final String? id;
  final String treeId;
  final String employeeName;
  final String employeeCode;
  final String? departmentUnitId;
  final String? directManagerUid;
  final bool active;
  final bool isPrimary;
  final int version;
}
