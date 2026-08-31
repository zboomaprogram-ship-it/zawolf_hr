import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_locations/domain/entities/attendance_location_assignment.dart';
import 'package:zawolf_hr/features/attendance_locations/domain/services/attendance_location_matcher.dart';

void main() {
  const matcher = AttendanceLocationMatcher();
  final now = DateTime.utc(2026, 8, 24, 8);

  AttendanceLocationAssignment assignment({
    required String id,
    required String locationId,
    required double latitude,
    bool active = true,
    DateTime? from,
    DateTime? to,
  }) => AttendanceLocationAssignment(
    id: id,
    employeeUid: 'employee-1',
    locationId: locationId,
    locationName: locationId,
    latitude: latitude,
    longitude: 31,
    radiusMeters: 80,
    version: 2,
    isActive: active,
    effectiveFrom: from,
    effectiveTo: to,
  );

  test('selects the nearest effective assigned location', () {
    final result = matcher.nearestMatch(
      assignments: [
        assignment(id: 'employee-1_B', locationId: 'B', latitude: 30.0003),
        assignment(id: 'employee-1_A', locationId: 'A', latitude: 30.0001),
      ],
      employeeUid: 'employee-1',
      eventTime: now,
      latitude: 30,
      longitude: 31,
      accuracyMeters: 5,
    );
    expect(result?.locationId, 'A');
    expect(result?.assignmentVersion, 2);
  });

  test('supports more than two assigned attendance locations', () {
    final result = matcher.nearestMatch(
      assignments: [
        assignment(id: 'employee-1_A', locationId: 'A', latitude: 30.0030),
        assignment(id: 'employee-1_B', locationId: 'B', latitude: 30.0020),
        assignment(id: 'employee-1_C', locationId: 'C', latitude: 30.0001),
      ],
      employeeUid: 'employee-1',
      eventTime: now,
      latitude: 30,
      longitude: 31,
      accuracyMeters: 5,
    );
    expect(result?.locationId, 'C');
  });

  test('uses stable location id to break equal-distance overlaps', () {
    final result = matcher.nearestMatch(
      assignments: [
        assignment(id: 'employee-1_B', locationId: 'B', latitude: 30),
        assignment(id: 'employee-1_A', locationId: 'A', latitude: 30),
      ],
      employeeUid: 'employee-1',
      eventTime: now,
      latitude: 30,
      longitude: 31,
      accuracyMeters: 5,
    );
    expect(result?.locationId, 'A');
  });

  test('ignores inactive and not-yet-effective assignments', () {
    final result = matcher.nearestMatch(
      assignments: [
        assignment(
          id: 'inactive',
          locationId: 'A',
          latitude: 30,
          active: false,
        ),
        assignment(
          id: 'future',
          locationId: 'B',
          latitude: 30,
          from: now.add(const Duration(minutes: 1)),
        ),
      ],
      employeeUid: 'employee-1',
      eventTime: now,
      latitude: 30,
      longitude: 31,
      accuracyMeters: 5,
    );
    expect(result, isNull);
  });

  test('returns no match for an empty or outside assignment set', () {
    expect(
      matcher.nearestMatch(
        assignments: const [],
        employeeUid: 'employee-1',
        eventTime: now,
        latitude: 30,
        longitude: 31,
        accuracyMeters: 5,
      ),
      isNull,
    );
    expect(
      matcher.nearestMatch(
        assignments: [assignment(id: 'far', locationId: 'far', latitude: 31)],
        employeeUid: 'employee-1',
        eventTime: now,
        latitude: 30,
        longitude: 31,
        accuracyMeters: 5,
      ),
      isNull,
    );
  });

  test('uses absolute instants across Cairo daylight-saving boundaries', () {
    final startsAtMidnightAfterDst = DateTime.parse(
      '2026-10-30T00:00:00+02:00',
    );
    final candidate = assignment(
      id: 'dst',
      locationId: 'dst',
      latitude: 30,
      from: startsAtMidnightAfterDst,
    );
    expect(
      matcher.nearestMatch(
        assignments: [candidate],
        employeeUid: 'employee-1',
        eventTime: DateTime.parse('2026-10-29T23:59:59+02:00'),
        latitude: 30,
        longitude: 31,
        accuracyMeters: 5,
      ),
      isNull,
    );
    expect(
      matcher
          .nearestMatch(
            assignments: [candidate],
            employeeUid: 'employee-1',
            eventTime: DateTime.parse('2026-10-30T00:00:00+02:00'),
            latitude: 30,
            longitude: 31,
            accuracyMeters: 5,
          )
          ?.locationId,
      'dst',
    );
  });
}
