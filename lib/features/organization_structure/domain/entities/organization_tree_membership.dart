class OrganizationTreeMembership {
  const OrganizationTreeMembership({
    required this.id,
    required this.treeId,
    required this.employeeUid,
    required this.unitId,
    required this.version,
    this.directManagerUid,
    this.title,
    this.isPrimary = false,
    this.active = true,
  });

  final String id;
  final String treeId;
  final String employeeUid;
  final String unitId;
  final String? directManagerUid;
  final String? title;
  final bool isPrimary;
  final bool active;
  final int version;

  OrganizationTreeMembership copyWith({
    String? id,
    String? treeId,
    String? employeeUid,
    String? unitId,
    String? directManagerUid,
    String? title,
    bool? isPrimary,
    bool? active,
    int? version,
  }) {
    return OrganizationTreeMembership(
      id: id ?? this.id,
      treeId: treeId ?? this.treeId,
      employeeUid: employeeUid ?? this.employeeUid,
      unitId: unitId ?? this.unitId,
      directManagerUid: directManagerUid ?? this.directManagerUid,
      title: title ?? this.title,
      isPrimary: isPrimary ?? this.isPrimary,
      active: active ?? this.active,
      version: version ?? this.version,
    );
  }
}
