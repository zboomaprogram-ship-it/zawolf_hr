final class OperationalVisibilitySetting {
  const OperationalVisibilitySetting({
    required this.employeeUserId,
    required this.hiddenFromAttendance,
    required this.version,
    this.reasonAr,
    this.updatedAt,
  });

  final String employeeUserId;
  final bool hiddenFromAttendance;
  final int version;
  final String? reasonAr;
  final DateTime? updatedAt;

  bool get remainsActiveAccount => true;
}
