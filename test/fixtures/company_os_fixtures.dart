import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/models/user_model.dart';

UserModel companyOsUser({
  required String uid,
  required String role,
  String? managerId,
  List<String> managerIds = const [],
  bool active = true,
  String department = 'Engineering',
}) {
  return UserModel(
    uid: uid,
    email: '$uid@example.test',
    displayName: uid,
    role: role,
    employeeId: uid.toUpperCase(),
    department: department,
    position: role,
    locationId: 'location-1',
    locationName: 'Test Office',
    managerId: managerId,
    managerIds: managerIds,
    isActive: active,
    workSchedule: WorkSchedule(),
    leaveBalance: LeaveBalance(annual: 15, sick: 14, casual: 7, daysOff: 15),
    permissionBalance: PermissionBalance(
      usedThisMonth: 0,
      usedHoursThisMonth: 0,
      lastResetMonth: '',
    ),
  );
}

final companyOsIdentityFixtures = <String, UserModel>{
  'employee': companyOsUser(
    uid: 'employee-1',
    role: EmployeeRole.employee,
    managerId: 'manager-1',
    managerIds: const ['manager-1'],
  ),
  'itSupport': companyOsUser(uid: 'it-support-1', role: 'it_support'),
  'itManager': companyOsUser(uid: 'it-manager-1', role: 'it_manager'),
  'finance': companyOsUser(uid: 'finance-1', role: 'finance'),
  'manager': companyOsUser(uid: 'manager-1', role: EmployeeRole.manager),
  'admin': companyOsUser(uid: 'admin-1', role: EmployeeRole.hrAdmin),
  'superAdmin': companyOsUser(
    uid: 'super-admin-1',
    role: EmployeeRole.superAdmin,
  ),
  'inactive': companyOsUser(
    uid: 'inactive-1',
    role: EmployeeRole.employee,
    active: false,
  ),
  'outOfScope': companyOsUser(
    uid: 'employee-2',
    role: EmployeeRole.employee,
    department: 'Sales',
  ),
};
