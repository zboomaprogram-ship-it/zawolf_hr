class AttendanceLocationMatchEvidence {
  const AttendanceLocationMatchEvidence({
    required this.assignmentId,
    required this.assignmentVersion,
    required this.locationId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  final String assignmentId;
  final int assignmentVersion;
  final String locationId;
  final String locationName;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double distanceMeters;
  final double allowedRadiusMeters;
}
