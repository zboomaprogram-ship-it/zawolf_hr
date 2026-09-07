import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/models/user_model.dart';
import 'package:zawolf_hr/services/advance_service.dart';

UserModel employee({DateTime? joined, double salary = 10000}) => UserModel(
  uid: 'employee-1',
  email: 'employee@example.com',
  displayName: 'موظف',
  role: EmployeeRole.employee,
  employeeId: 'EMP-1',
  department: 'Operations',
  position: 'Employee',
  locationId: 'HQ',
  locationName: 'HQ',
  joinDate: joined,
  baseMonthlySalary: salary,
  workSchedule: WorkSchedule(),
  leaveBalance: LeaveBalance(annual: 15, sick: 14, casual: 7, daysOff: 15),
  permissionBalance: PermissionBalance(
    usedThisMonth: 0,
    usedHoursThisMonth: 0,
    lastResetMonth: '',
  ),
);

void main() {
  final eligibleAt = DateTime(2026, 9, 15, 10);

  test('advance rule accepts exactly three months and half salary', () {
    expect(
      () => AdvanceService.validateSubmissionEligibility(
        employee: employee(joined: DateTime(2026, 6, 17)),
        amount: 5000,
        now: eligibleAt,
      ),
      returnsNormally,
    );
  });

  test('advance rule denies before tenure, before day 15, and above cap', () {
    expect(
      () => AdvanceService.validateSubmissionEligibility(
        employee: employee(joined: DateTime(2026, 6, 18)),
        amount: 5000,
        now: eligibleAt,
      ),
      throwsException,
    );
    expect(
      () => AdvanceService.validateSubmissionEligibility(
        employee: employee(joined: DateTime(2025, 1, 1)),
        amount: 5000,
        now: DateTime(2026, 9, 14, 10),
      ),
      throwsException,
    );
    expect(
      () => AdvanceService.validateSubmissionEligibility(
        employee: employee(joined: DateTime(2025, 1, 1)),
        amount: 5000.01,
        now: eligibleAt,
      ),
      throwsException,
    );
  });

  test('submission validates before allocating a Firestore request document', () {
    final source = File('lib/services/advance_service.dart').readAsStringSync();
    final submitStart = source.indexOf('Future<void> submitAdvanceRequest');
    final validation = source.indexOf(
      'validateSubmissionEligibility(employee: employee, amount: req.amount, now: now);',
      submitStart,
    );
    final write = source.indexOf(
      "_db.collection('advances').doc()",
      submitStart,
    );
    expect(validation, lessThan(write));
  });
}
