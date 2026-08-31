import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_locations/domain/entities/attendance_location_assignment.dart';
import 'package:zawolf_hr/features/attendance_locations/domain/services/attendance_region_plan.dart';

void main() {
  AttendanceLocationAssignment assignment(
    String id, {
    int priority = 0,
    bool isDefault = false,
    bool active = true,
  }) => AttendanceLocationAssignment(
    id: 'u_$id',
    employeeUid: 'u',
    locationId: id,
    locationName: id,
    latitude: 30,
    longitude: 31,
    radiusMeters: 50,
    version: 1,
    priority: priority,
    isDefault: isDefault,
    isActive: active,
  );

  test('prioritizes default then priority then stable location id', () {
    final result = AttendanceRegionPlan.build(
      assignments: [
        assignment('z', priority: 1),
        assignment('b'),
        assignment('a'),
        assignment('default', priority: 99, isDefault: true),
      ],
      at: DateTime.utc(2026, 8, 24),
    );
    expect(result.map((item) => item.locationId), ['default', 'a', 'b', 'z']);
  });

  test('filters inactive assignments and caps native regions at twenty', () {
    final result = AttendanceRegionPlan.build(
      assignments: [
        for (var index = 0; index < 25; index++)
          assignment('L${index.toString().padLeft(2, '0')}', priority: index),
        assignment('inactive', active: false),
      ],
      at: DateTime.utc(2026, 8, 24),
      limit: 99,
    );
    expect(result, hasLength(20));
    expect(result.any((item) => item.locationId == 'inactive'), isFalse);
  });
}
