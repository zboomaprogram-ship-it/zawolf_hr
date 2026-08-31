import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_snapshot.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_membership.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_change_set.dart';
import 'package:zawolf_hr/features/organization_structure/domain/entities/organization_unit.dart';
import 'package:zawolf_hr/features/organization_structure/domain/services/organization_hierarchy_policy.dart';

void main() {
  const policy = OrganizationHierarchyPolicy();
  const sector = OrganizationUnit(
    id: 's1',
    type: OrganizationUnitType.sector,
    name: 'الإدارة',
    order: 0,
    version: 1,
  );
  const department = OrganizationUnit(
    id: 'd1',
    type: OrganizationUnitType.department,
    name: 'الموارد البشرية',
    parentId: 's1',
    order: 0,
    version: 1,
  );

  test('stable IDs and containment survive display-name changes', () {
    final renamed = department.copyWith(name: 'شؤون الأفراد', version: 2);
    expect(renamed.id, department.id);
    expect(renamed.parentId, sector.id);
    expect(renamed.version, 2);
  });

  test('snapshot order is deterministic and archived units are hidden', () {
    final snapshot = OrganizationSnapshot(
      units: [
        department.copyWith(archived: true),
        sector,
        const OrganizationUnit(
          id: 'd2',
          type: OrganizationUnitType.department,
          name: 'التقنية',
          parentId: 's1',
          order: 2,
          version: 1,
        ),
        const OrganizationUnit(
          id: 'd0',
          type: OrganizationUnitType.department,
          name: 'الإدارة',
          parentId: 's1',
          order: 1,
          version: 1,
        ),
      ],
      memberships: const [],
      version: 4,
      loadedAt: DateTime(2026),
    );
    expect(snapshot.departmentsFor('s1').map((item) => item.id), ['d0', 'd2']);
  });

  test('manager vacancy is explicit and allowed', () {
    expect(department.hasVacantManager, true);
    expect(department.copyWith(managerUid: 'm1').hasVacantManager, false);
  });

  test('normalized names are unique only within the same parent and type', () {
    final issue = policy.validateName(
      candidate: const OrganizationUnit(
        id: 'd2',
        type: OrganizationUnitType.department,
        name: '  الموارد   البشرية  ',
        parentId: 's1',
        order: 1,
        version: 1,
      ),
      units: [
        sector,
        department.copyWith(name: 'الموارد البشرية'),
      ],
    );
    expect(issue?.code, OrganizationValidationCode.duplicateName);
    expect(
      policy.validateName(
        candidate: department.copyWith(name: 'التقنية'),
        units: [sector, department],
      ),
      isNull,
    );
  });

  test('two-level containment rejects invalid parents and self cycles', () {
    expect(
      policy
          .validateContainment(
            candidate: department.copyWith(parentId: 'missing'),
            units: [sector, department],
          )
          ?.code,
      OrganizationValidationCode.invalidContainment,
    );
    expect(
      policy
          .validateContainment(
            candidate: department.copyWith(parentId: department.id),
            units: [sector, department],
          )
          ?.code,
      OrganizationValidationCode.hierarchyCycle,
    );
  });

  test('archive requires no children, members, or assigned manager', () {
    const membership = OrganizationMembership(
      employeeUid: 'u1',
      employeeName: 'موظف',
      employeeCode: 'E-1',
      departmentUnitId: 'd1',
    );
    expect(
      policy
          .validateArchive(
            candidate: department,
            units: [sector, department],
            memberships: [membership],
          )
          ?.code,
      OrganizationValidationCode.unitHasDependencies,
    );
    expect(
      policy.validateArchive(
        candidate: department,
        units: [sector, department],
        memberships: const [],
      ),
      isNull,
    );
  });
}
