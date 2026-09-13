import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = File('firestore.rules').readAsStringSync();
  final screen =
      File('lib/screens/manager/requests_mgmt.dart').readAsStringSync();

  test('legacy employee-code reviewers are authorized consistently', () {
    expect(rules, contains('function employeeCode()'));
    expect(rules, contains('function isCurrentApprovalManager()'));
    expect(rules, contains("employeeCode() == 'COO-1300'"));
    expect(rules, contains('managerIds[currentIndex] == employeeCode()'));
    expect(
      rules,
      contains('resource.data.get(\'managerId\', \'\') == employeeCode()'),
    );
  });

  test('CEO and COO can read every request-management collection', () {
    expect(rules, contains('isCompanyExecutive()'));
    expect(rules, contains('match /leaves/{leaveId}'));
    expect(rules, contains('match /permissions/{permissionId}'));
    expect(rules, contains('match /administrativeRequests/{requestId}'));
    expect(rules, contains('match /advances/{advanceId}'));
  });

  test('inspection does not render an action for another manager stage', () {
    expect(screen, contains('return isAssignedManager || isSuperAdmin;'));
    expect(
      screen,
      contains('return isAssignedManager || EmployeeRole.isHr(reviewer.role);'),
    );
  });

  test('COO-1300 request inbox is limited to its assigned approval stage', () {
    expect(screen, contains('if (reviewer.isCompanyCoo)'));
    expect(screen, contains('_canActOnApproval(doc.data(), reviewer)'));
    expect(
      screen,
      contains("whereIn: const ['pending_manager', 'pending_coo']"),
    );
  });
}
