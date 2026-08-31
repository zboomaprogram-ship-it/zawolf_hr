enum OrganizationTreeStatus { draft, active, archived }

class OrganizationTree {
  const OrganizationTree({
    required this.id,
    required this.name,
    required this.status,
    required this.version,
    this.purpose,
    this.rootLeaderUid,
    this.treeAdminUids = const [],
    this.isDefault = false,
    this.order = 0,
  });

  final String id;
  final String name;
  final String? purpose;
  final String? rootLeaderUid;
  final List<String> treeAdminUids;
  final OrganizationTreeStatus status;
  final int version;
  final bool isDefault;
  final int order;

  OrganizationTree copyWith({
    String? id,
    String? name,
    String? purpose,
    String? rootLeaderUid,
    List<String>? treeAdminUids,
    OrganizationTreeStatus? status,
    int? version,
    bool? isDefault,
    int? order,
  }) {
    return OrganizationTree(
      id: id ?? this.id,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      rootLeaderUid: rootLeaderUid ?? this.rootLeaderUid,
      treeAdminUids: treeAdminUids ?? this.treeAdminUids,
      status: status ?? this.status,
      version: version ?? this.version,
      isDefault: isDefault ?? this.isDefault,
      order: order ?? this.order,
    );
  }
}
