/// A minimal, non-sensitive employee identity shown to an authorized grantor.
///
/// This is intentionally separate from the full employee profile so the
/// developer-tools page cannot expose payroll, attendance, device, or location
/// information while selecting a recipient.
final class DeveloperToolsEmployee {
  const DeveloperToolsEmployee({
    required this.userId,
    required this.displayName,
    required this.employeeCode,
    required this.department,
  });

  final String userId;
  final String displayName;
  final String employeeCode;
  final String department;

  String get label =>
      '$displayName${employeeCode.isEmpty ? '' : ' · $employeeCode'}';
}
