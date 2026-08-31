import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/services/managed_employee_service.dart';

import '../../fixtures/company_os_fixtures.dart';

void main() {
  test('legacy HR Manager is normalized to ordinary HR', () {
    expect(EmployeeRole.normalize(EmployeeRole.legacyHrManager), 'hr_admin');
  });

  test('existing active employee identity retains manager relationship', () {
    final employee = companyOsIdentityFixtures['employee']!;
    expect(employee.isActive, isTrue);
    expect(employee.department, 'Engineering');
    expect(ManagedEmployeeService.isManagedBy(employee, 'manager-1'), isTrue);
    expect(ManagedEmployeeService.isManagedBy(employee, 'manager-2'), isFalse);
  });

  test('inactive employment remains explicit in the authoritative profile', () {
    expect(companyOsIdentityFixtures['inactive']!.isActive, isFalse);
  });
}
