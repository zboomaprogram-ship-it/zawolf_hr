class EmployeeRole {
  static const employee = 'employee';
  static const teamLeader = 'team_leader';
  static const manager = 'manager';
  static const hrAdmin = 'hr_admin';
  static const superAdmin = 'super_admin';

  static bool isSuperAdmin(String? role) => role == superAdmin;
  static bool isHr(String? role) => role == hrAdmin || role == superAdmin;
  static bool isManager(String? role) => role == manager || role == superAdmin;
  static bool isTeamLeader(String? role) => role == teamLeader;
  static bool hasTeamScope(String? role) =>
      role == teamLeader || role == manager || role == superAdmin;

  static String arabicLabel(String role) {
    switch (role) {
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
