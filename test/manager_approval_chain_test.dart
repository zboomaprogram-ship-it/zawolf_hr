import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/models/manager_approval_chain.dart';

void main() {
  group('manager approval chain', () {
    test('preserves low-to-high order and removes duplicates', () {
      expect(
        ManagerApprovalChain.orderedIds([
          'direct-manager',
          'higher-manager',
          'direct-manager',
        ]),
        ['direct-manager', 'higher-manager'],
      );
    });

    test('uses legacy direct manager only when list is empty', () {
      expect(
        ManagerApprovalChain.orderedIds([], fallbackId: 'legacy-manager'),
        ['legacy-manager'],
      );
    });

    test('places the assigned team leader before managers', () {
      expect(
        ManagerApprovalChain.orderedIds([
          'direct-manager',
          'higher-manager',
        ], teamLeaderId: 'team-leader'),
        ['team-leader', 'direct-manager', 'higher-manager'],
      );
      expect(
        EmployeeRole.canActAsApprovalManager(EmployeeRole.teamLeader),
        isTrue,
      );
    });

    test('ignores a stale saved index and follows current manager id', () {
      expect(
        ManagerApprovalChain.nextIndex(
          managerIds: ['low', 'high'],
          currentManagerId: 'low',
          savedIndex: 1,
        ),
        1,
      );
    });
  });

  group('HR Manager capabilities', () {
    test('can manage privileged accounts and access reports', () {
      expect(
        EmployeeRole.canManagePrivilegedAccounts(EmployeeRole.hrManager),
        isTrue,
      );
      expect(EmployeeRole.canAccessReports(EmployeeRole.hrManager), isTrue);
    });

    test('normal HR cannot create privileged accounts or access reports', () {
      expect(
        EmployeeRole.canManagePrivilegedAccounts(EmployeeRole.hrAdmin),
        isFalse,
      );
      expect(EmployeeRole.canAccessReports(EmployeeRole.hrAdmin), isFalse);
    });
  });
}
