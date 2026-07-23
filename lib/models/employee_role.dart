class EmployeeRole {
  static const employee = 'employee';
  static const teamLeader = 'team_leader';
  static const manager = 'manager';
  static const hrAdmin = 'hr_admin';
  static const hrManager = 'hr_manager';
  static const superAdmin = 'super_admin';

  static bool isSuperAdmin(String? role) => role == superAdmin;
  static bool isHrStaff(String? role) => role == hrAdmin || role == hrManager;
  static bool isHr(String? role) => isHrStaff(role) || role == superAdmin;
  static bool isHrManager(String? role) => role == hrManager;
  static bool canManagePrivilegedAccounts(String? role) =>
      role == hrManager || role == superAdmin;
  static bool canAccessReports(String? role) =>
      role == hrManager || role == superAdmin;
  static bool canActAsApprovalManager(String? role) =>
      role == teamLeader ||
      role == manager ||
      role == hrAdmin ||
      role == hrManager ||
      role == superAdmin;
  static bool isManager(String? role) =>
      role == manager || role == hrManager || role == superAdmin;
  static bool isTeamLeader(String? role) => role == teamLeader;
  static bool hasTeamScope(String? role) =>
      role == teamLeader ||
      role == manager ||
      role == hrManager ||
      role == superAdmin;

  static String arabicLabel(String role) {
    switch (role) {
      case superAdmin:
        return 'مالك النظام';
      case hrAdmin:
        return 'مسؤول HR';
      case hrManager:
        return 'مدير HR';
      case manager:
        return 'مدير قسم';
      case teamLeader:
        return 'قائد فريق';
      default:
        return 'موظف';
    }
  }
}
