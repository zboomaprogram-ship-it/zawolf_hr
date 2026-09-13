class RequestStaffingConflict {
  const RequestStaffingConflict({
    required this.employeeName,
    required this.requestType,
    required this.date,
  });
  final String employeeName, requestType, date;
}

String normalizeStaffingJobTitle(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
