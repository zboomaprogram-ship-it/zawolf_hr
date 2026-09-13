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

class ManualAttendanceBatchResult {
  const ManualAttendanceBatchResult({
    required this.recorded,
    required this.failed,
    required this.results,
  });
  final int recorded;
  final int failed;
  final List<ManualAttendanceBatchEmployeeResult> results;
}

class ManualAttendanceBatchEmployeeResult {
  const ManualAttendanceBatchEmployeeResult({
    required this.employeeId,
    required this.ok,
    this.error,
  });
  final String employeeId;
  final bool ok;
  final String? error;
}

abstract interface class ManualAttendanceRepository {
  Future<List<ManualAttendanceEmployee>> findEmployees(String query);

  Future<ManualAttendanceBatchResult> recordBatch({
    required List<String> employeeIds,
    required String eventType,
    required DateTime effectiveAt,
    required String reason,
  });

  Future<void> record({
    required String employeeId,
    required String eventType, // 'checkIn', 'checkOut', or 'disableCheckOut'
    required DateTime effectiveAt,
    required String reason,
  });
}
