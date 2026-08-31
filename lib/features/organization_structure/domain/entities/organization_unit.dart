enum OrganizationUnitType { sector, department }

final class OrganizationUnit {
  const OrganizationUnit({
    required this.id,
    required this.type,
    required this.name,
    required this.order,
    required this.version,
    this.treeId = 'default',
    this.parentId,
    this.managerUid,
    this.memberCount = 0,
    this.archived = false,
  });

  final String id;
  final String treeId;
  final OrganizationUnitType type;
  final String name;
  final String? parentId;
  final String? managerUid;
  final int memberCount;
  final int order;
  final int version;
  final bool archived;

  bool get hasVacantManager =>
      type == OrganizationUnitType.department &&
      (managerUid == null || managerUid!.isEmpty);

  OrganizationUnit copyWith({
    String? treeId,
    String? name,
    String? parentId,
    String? managerUid,
    int? order,
    int? version,
    int? memberCount,
    bool? archived,
    bool clearManager = false,
  }) => OrganizationUnit(
    id: id,
    treeId: treeId ?? this.treeId,
    type: type,
    name: name ?? this.name,
    parentId: parentId ?? this.parentId,
    managerUid: clearManager ? null : managerUid ?? this.managerUid,
    memberCount: memberCount ?? this.memberCount,
    order: order ?? this.order,
    version: version ?? this.version,
    archived: archived ?? this.archived,
  );
}
