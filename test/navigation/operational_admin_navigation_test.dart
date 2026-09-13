import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/navigation/nav_config.dart';

void main() {
  const expectedPaths = <String>[
    '/hr/manual-attendance',
    '/hr/attendance-policy',
    '/hr/field-assignments',
    '/hr/meeting-rooms',
    '/meeting/approvals',
    '/meeting/history',
    '/hr/custom-request-types',
    '/hr/organization-trees',
    '/hr/custom-badges',
    '/company-os',
    '/workspace',
    '/hr/developer-tools',
    '/hr/developer-api',
    '/hr/diagnostics',
  ];

  for (final role in <String>[EmployeeRole.hrAdmin, EmployeeRole.superAdmin]) {
    test('operational administration features are visible to $role', () {
      final paths = navItemsForRole(role).map((item) => item.path).toSet();
      for (final path in expectedPaths) {
        expect(paths, contains(path));
      }
    });
  }
}
