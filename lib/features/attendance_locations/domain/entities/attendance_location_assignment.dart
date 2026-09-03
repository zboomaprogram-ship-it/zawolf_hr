class AttendanceLocationAssignment {
  const AttendanceLocationAssignment({
    required this.id,
    required this.employeeUid,
    required this.locationId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.version,
    this.employeeName = '',
    this.employeeCode = '',
    this.priority = 0,
    this.isDefault = false,
    this.isActive = true,
    this.locationIsActive = true,
    this.effectiveFrom,
    this.effectiveTo,
  });

  final String id;
  final String employeeUid;
  final String locationId;
  final String locationName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int version;
  final String employeeName;
  final String employeeCode;
  final int priority;
  final bool isDefault;
  final bool isActive;
  final bool locationIsActive;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  bool isEffectiveAt(DateTime instant) {
    if (!isActive || !locationIsActive) return false;
    final starts = effectiveFrom;
    final ends = effectiveTo;
    if (starts != null && instant.isBefore(starts)) return false;
    if (ends != null && instant.isAfter(ends)) return false;
    return true;
  }
}
