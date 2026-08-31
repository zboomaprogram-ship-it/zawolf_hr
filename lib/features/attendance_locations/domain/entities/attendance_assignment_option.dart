class AttendanceEmployeeOption {
  const AttendanceEmployeeOption({
    required this.uid,
    required this.name,
    required this.employeeCode,
    required this.department,
  });

  final String uid;
  final String name;
  final String employeeCode;
  final String department;
}

class AttendanceSiteOption {
  const AttendanceSiteOption({required this.id, required this.name});

  final String id;
  final String name;
}
