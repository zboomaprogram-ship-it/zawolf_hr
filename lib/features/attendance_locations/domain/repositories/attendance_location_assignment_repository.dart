import '../entities/attendance_location_assignment.dart';

abstract interface class AttendanceLocationAssignmentRepository {
  Future<AttendanceLocationAssignmentsSnapshot> getMine({bool refresh = false});
}

class AttendanceLocationAssignmentsSnapshot {
  const AttendanceLocationAssignmentsSnapshot({
    required this.enabled,
    required this.assignments,
    this.fromCache = false,
    this.isStale = false,
  });

  final bool enabled;
  final List<AttendanceLocationAssignment> assignments;
  final bool fromCache;
  final bool isStale;
}

abstract interface class AttendanceLocationAdministrationRepository {
  Future<List<AttendanceLocationAssignment>> listAssignments(
    String employeeUid,
  );
  Future<List<AttendanceLocationAssignment>> listAllAssignments();

  Future<Map<String, dynamic>> previewAssignments({
    required List<String> employeeUids,
    required List<String> locationIds,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  });

  Future<Map<String, dynamic>> applyAssignments({
    required String operationId,
    required String previewToken,
    required List<String> employeeUids,
    required List<String> locationIds,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  });
}
