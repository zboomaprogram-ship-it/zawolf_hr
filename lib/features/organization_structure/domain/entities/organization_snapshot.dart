import 'organization_membership.dart';
import 'organization_unit.dart';
import 'organization_tree.dart';

final class OrganizationSnapshot {
  const OrganizationSnapshot({
    required this.units,
    required this.memberships,
    required this.version,
    required this.loadedAt,
    this.trees = const [],
    this.selectedTreeId,
  });
  final List<OrganizationUnit> units;
  final List<OrganizationMembership> memberships;
  final int version;
  final DateTime loadedAt;
  final List<OrganizationTree> trees;
  final String? selectedTreeId;

  List<OrganizationUnit> get sectors =>
      units
          .where(
            (unit) =>
                unit.type == OrganizationUnitType.sector && !unit.archived,
          )
          .toList(growable: false)
        ..sort((a, b) => a.order.compareTo(b.order));

  List<OrganizationUnit> departmentsFor(String sectorId) =>
      units
          .where(
            (unit) =>
                unit.type == OrganizationUnitType.department &&
                unit.parentId == sectorId &&
                !unit.archived,
          )
          .toList(growable: false)
        ..sort((a, b) => a.order.compareTo(b.order));
}
