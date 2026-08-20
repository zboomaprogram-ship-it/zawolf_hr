class EmployeeRole {
  static const employee = 'employee';
  static const teamLeader = 'team_leader';
  static const manager = 'manager';
  static const hrAdmin = 'hr_admin';

  /// Compatibility alias. New and edited accounts are always stored as HR.
  static const hrManager = hrAdmin;
  static const legacyHrManager = 'hr_manager';
  static const superAdmin = 'super_admin';

  static bool isSuperAdmin(String? role) => role == superAdmin;
  static String normalize(String? role) =>
      role == legacyHrManager ? hrAdmin : (role ?? employee);
  static bool isHrStaff(String? role) => normalize(role) == hrAdmin;
  static bool isHr(String? role) => isHrStaff(role) || role == superAdmin;
  static bool isHrManager(String? role) => isHrStaff(role);
  static bool canManagePrivilegedAccounts(String? role) =>
      isHrStaff(role) || role == superAdmin;
  static bool canAccessReports(String? role) =>
      isHrStaff(role) || role == superAdmin;
  static bool canActAsApprovalManager(String? role) =>
      role == teamLeader ||
      role == manager ||
      isHrStaff(role) ||
      role == superAdmin;
  static bool isManager(String? role) =>
      role == manager || isHrStaff(role) || role == superAdmin;
  static bool isTeamLeader(String? role) => role == teamLeader;
  static bool hasTeamScope(String? role) =>
      role == teamLeader ||
      role == manager ||
      isHrStaff(role) ||
      role == superAdmin;

  static String arabicLabel(String role) {
    switch (normalize(role)) {
      case superAdmin:
        return 'مالك النظام';
      case hrAdmin:
        return 'مسؤول HR';
      case manager:
        return 'مدير قسم';
      case teamLeader:
        return 'قائد فريق';
      default:
        return 'موظف';
    }
  }
}
