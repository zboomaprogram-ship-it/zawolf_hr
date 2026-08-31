import 'dart:math' as math;

import '../entities/attendance_location_assignment.dart';
import '../entities/attendance_location_match_evidence.dart';

class AttendanceLocationMatcher {
  const AttendanceLocationMatcher();

  AttendanceLocationMatchEvidence? nearestMatch({
    required List<AttendanceLocationAssignment> assignments,
    required String employeeUid,
    required DateTime eventTime,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    double maxAccuracyAllowanceMeters = 12,
  }) {
    final matches = <AttendanceLocationMatchEvidence>[];
    for (final assignment in assignments) {
      if (assignment.employeeUid != employeeUid ||
          !assignment.isEffectiveAt(eventTime)) {
        continue;
      }
      final distance = _distanceMeters(
        latitude,
        longitude,
        assignment.latitude,
        assignment.longitude,
      );
      final radius =
          assignment.radiusMeters +
          accuracyMeters.clamp(0, maxAccuracyAllowanceMeters);
      if (distance > radius) continue;
      matches.add(
        AttendanceLocationMatchEvidence(
          assignmentId: assignment.id,
          assignmentVersion: assignment.version,
          locationId: assignment.locationId,
          locationName: assignment.locationName,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          distanceMeters: distance,
          allowedRadiusMeters: radius,
        ),
      );
    }
    matches.sort((left, right) {
      final distance = left.distanceMeters.compareTo(right.distanceMeters);
      return distance != 0
          ? distance
          : left.locationId.compareTo(right.locationId);
    });
    return matches.firstOrNull;
  }

  double _distanceMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _radians(latitudeA);
    final lat2 = _radians(latitudeB);
    final deltaLat = _radians(latitudeB - latitudeA);
    final deltaLng = _radians(longitudeB - longitudeA);
    final haversine =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
