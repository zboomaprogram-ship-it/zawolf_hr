import '../entities/attendance_location_assignment.dart';

class AttendanceRegionPlan {
  const AttendanceRegionPlan._();

  static const platformLimit = 20;

  static List<AttendanceLocationAssignment> build({
    required List<AttendanceLocationAssignment> assignments,
    required DateTime at,
    int limit = platformLimit,
  }) {
    final active =
        assignments
            .where((assignment) => assignment.isEffectiveAt(at))
            .toList(growable: true)
          ..sort((a, b) {
            if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
            final priority = a.priority.compareTo(b.priority);
            return priority != 0
                ? priority
                : a.locationId.compareTo(b.locationId);
          });
    return active.take(limit.clamp(0, platformLimit)).toList(growable: false);
  }
}
