import '../entities/check_in_location.dart';

/// Pure domain contract for verifying device location against assigned branch geofences.
abstract interface class GeofenceVerificationRepository {
  /// Resolves device position and validates it against assigned geofence boundaries.
  Future<CheckInLocation> verifyLocation({
    required String employeeUid,
    required bool allowLastKnown,
  });
}
