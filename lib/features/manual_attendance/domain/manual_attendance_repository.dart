class ManualAttendanceEmployee {
  const ManualAttendanceEmployee({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.department,
    required this.email,
    required this.isCheckedIn,
    required this.isCheckedOut,
    this.checkInAt,
    this.checkOutAt,
  });

  final String id;
  final String name;
  final String employeeCode;
  final String department;
  final String email;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
}

abstract interface class ManualAttendanceRepository {
  Future<List<ManualAttendanceEmployee>> findEmployees(String query);

  Future<void> record({
    required String employeeId,
    required String eventType, // 'checkIn', 'checkOut', or 'disableCheckOut'
    required DateTime effectiveAt,
    required String reason,
  });
}
