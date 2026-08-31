import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/organization_structure.dart';

void main() {
  test('legacy defaults remain available as rollback input', () {
    expect(OrganizationDefaults.divisions, isNotEmpty);
    expect(
      OrganizationDefaults.divisions.map((item) => item.id).toSet().length,
      OrganizationDefaults.divisions.length,
    );
  });

  test('legacy organization levels preserve approval-related ordering', () {
    expect(OrganizationLevel.values, contains(OrganizationLevel.employee));
    expect(
      OrganizationLevel.values,
      contains(OrganizationLevel.departmentManager),
    );
    expect(OrganizationLevel.values, contains(OrganizationLevel.ceo));
  });
}
