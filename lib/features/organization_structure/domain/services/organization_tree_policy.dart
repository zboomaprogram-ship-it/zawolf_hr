import '../entities/organization_tree.dart';
import '../entities/organization_tree_membership.dart';

enum OrganizationTreeValidationCode {
  multiplePrimaryMemberships,
  multipleDefaultTrees,
}

class OrganizationTreePolicy {
  const OrganizationTreePolicy();

  OrganizationTreeValidationCode? validatePrimaryMemberships(
    Iterable<OrganizationTreeMembership> memberships,
  ) {
    final primaryCount = memberships
        .where((membership) => membership.active && membership.isPrimary)
        .length;
    return primaryCount > 1
        ? OrganizationTreeValidationCode.multiplePrimaryMemberships
        : null;
  }

  OrganizationTreeValidationCode? validateDefaultTree(
    Iterable<OrganizationTree> trees,
  ) {
    final defaultCount = trees
        .where(
          (tree) =>
              tree.status == OrganizationTreeStatus.active && tree.isDefault,
        )
        .length;
    return defaultCount > 1
        ? OrganizationTreeValidationCode.multipleDefaultTrees
        : null;
  }
}
