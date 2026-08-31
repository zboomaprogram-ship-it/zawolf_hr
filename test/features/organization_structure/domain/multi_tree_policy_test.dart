import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_tree.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_tree_membership.dart';
import 'package:zawolf_hr/features/organization_structure/domain/services/organization_tree_policy.dart';

void main() {
  const policy = OrganizationTreePolicy();

  test('employee can have memberships in many trees with one primary', () {
    const memberships = [
      OrganizationTreeMembership(
        id: 'a_u_d1',
        treeId: 'a',
        employeeUid: 'u',
        unitId: 'd1',
        version: 1,
        isPrimary: true,
      ),
      OrganizationTreeMembership(
        id: 'b_u_d2',
        treeId: 'b',
        employeeUid: 'u',
        unitId: 'd2',
        version: 1,
      ),
    ];
    expect(policy.validatePrimaryMemberships(memberships), isNull);
    expect(
      policy.validatePrimaryMemberships([
        memberships.first,
        memberships.last.copyWith(isPrimary: true),
      ]),
      OrganizationTreeValidationCode.multiplePrimaryMemberships,
    );
  });

  test('default active tree is unique', () {
    const trees = [
      OrganizationTree(
        id: 'a',
        name: 'A',
        status: OrganizationTreeStatus.active,
        version: 1,
        isDefault: true,
      ),
      OrganizationTree(
        id: 'b',
        name: 'B',
        status: OrganizationTreeStatus.active,
        version: 1,
        isDefault: true,
      ),
    ];
    expect(
      policy.validateDefaultTree(trees),
      OrganizationTreeValidationCode.multipleDefaultTrees,
    );
  });
}
