import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/user_model.dart';
import 'package:zawolf_hr/services/managed_employee_service.dart';

void main() {
  test('recognizes direct and higher assigned managers', () {
    final employee = UserModel(
      uid: 'employee',
      email: 'employee@example.com',
      displayName: 'Employee',
      role: 'employee',
      employeeId: 'EMP-1',
      department: 'Marketing',
      position: 'Specialist',
      locationId: 'seg',
      locationName: 'SEG',
      managerId: 'direct-manager',
      managerIds: ['direct-manager', 'higher-manager'],
      workSchedule: WorkSchedule(
        startTime: '09:00',
        endTime: '17:00',
        workDays: const [1, 2, 3, 4, 5, 6],
      ),
      leaveBalance: LeaveBalance(annual: 21, sick: 14, casual: 7, daysOff: 21),
      permissionBalance: PermissionBalance(
        usedThisMonth: 0,
        usedHoursThisMonth: 0,
        lastResetMonth: '2026-07',
      ),
    );

    expect(
      ManagedEmployeeService.isManagedBy(employee, 'direct-manager'),
      isTrue,
    );
    expect(
      ManagedEmployeeService.isManagedBy(employee, 'higher-manager'),
      isTrue,
    );
    expect(ManagedEmployeeService.isManagedBy(employee, 'other'), isFalse);
  });
}
