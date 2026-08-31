/// Non-production records used to characterize the mixed request data that
/// already exists in Firestore. Keep these free of Firebase types so unit tests
/// can exercise the normalizer without a Firebase emulator.
const pendingPermissionRequest = <String, dynamic>{
  'id': 'permission-pending-001',
  'employeeId': 'employee-001',
  'employeeCode': 'BD-1200',
  'employeeName': 'موظف تجريبي',
  'requestType': 'permission',
  'status': 'pending_manager',
  'requestDate': '2026-08-18',
  'startTime': '14:00',
  'endTime': '16:00',
  'createdAt': '2026-08-18T08:10:00.000Z',
};

const confirmedLateArrivalDeduction = <String, dynamic>{
  'id': 'late-deduction-confirmed-001',
  'employeeId': 'employee-002',
  'employeeCode': 'IT-400',
  'employeeName': 'موظف تقنية',
  'type': 'late_arrival_deduction',
  'status': 'confirmed',
  'attendanceDate': '2026-07-22',
  'approvalDate': '2026-08-02T10:28:00.000Z',
  'reason': 'تأخر حضور مثبت',
  'deductionFraction': 0.25,
  'amount': 0,
};

/// Legacy salary deductions used a mixture of names and omitted fields. The
/// reader must still classify and show these records without inventing values.
const legacyConfirmedSalaryDeduction = <String, dynamic>{
  'id': 'legacy-deduction-confirmed-001',
  'userId': 'employee-003',
  'employeeName': 'موظف قديم',
  'requestType': 'salary_deduction',
  'isConfirmed': true,
  'date': '2026-06-30',
  'createdAt': 1782777600000,
  'adminReason': 'مراجعة إدارية',
};

const mixedTimestampRequest = <String, dynamic>{
  'id': 'mixed-timestamp-001',
  'employeeId': 'employee-004',
  'requestType': 'attendance_correction',
  'status': 'hr_review',
  'requestDate': '2026-08-01',
  'createdAt': '2026-08-01T09:45:00.000Z',
  'updatedAt': 1785577500000,
};
