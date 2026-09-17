/// Pure Dart domain entity representing a validated attendance geofence position.
/// Framework-independent, free of Geolocator and device plugin dependencies.
class CheckInLocation {
  const CheckInLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isWithinZone,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.locationId,
    required this.locationName,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isWithinZone;
  final double distanceMeters;
  final double allowedRadiusMeters;
  final String locationId;
  final String locationName;
  final bool isMocked;
}
