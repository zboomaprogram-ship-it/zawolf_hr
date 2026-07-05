class EmployeeRole {
  static const employee = 'employee';
  static const manager = 'manager';
  static const hrAdmin = 'hr_admin';
  static const superAdmin = 'super_admin';

  static bool isSuperAdmin(String? role) => role == superAdmin;
  static bool isHr(String? role) => role == hrAdmin || role == superAdmin;
  static bool isManager(String? role) => role == manager || role == superAdmin;

  static String arabicLabel(String role) {
    switch (role) {
      case superAdmin:
        return 'مالك النظام';
      case hrAdmin:
        return 'مسؤول HR';
      case manager:
        return 'مدير قسم';
      default:
        return 'موظف';
    }
  }
}
