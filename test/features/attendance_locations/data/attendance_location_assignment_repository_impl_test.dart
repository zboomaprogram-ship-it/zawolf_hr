import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/attendance_locations/data/attendance_location_assignment_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> responseBody() => {
    'ok': true,
    'enabled': true,
    'assignments': [
      {
        'id': 'u_l1',
        'employeeUid': 'u',
        'locationId': 'l1',
        'locationName': 'المقر',
        'latitude': 30,
        'longitude': 31,
        'radiusMeters': 80,
        'version': 3,
        'isActive': true,
        'locationIsActive': true,
      },
    ],
  };

  test('stores a fresh bounded assignment response', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AttendanceLocationAssignmentRepositoryImpl(
      client: AuthenticatedOperationClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(responseBody()),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        tokenProvider: () async => 'token',
      ),
    );

    final snapshot = await repository.getMine();

    expect(snapshot.enabled, isTrue);
    expect(snapshot.fromCache, isFalse);
    expect(snapshot.assignments.single.version, 3);
  });

  test('uses cached assignments when the network is interrupted', () async {
    SharedPreferences.setMockInitialValues({
      'attendance_location_assignments_v1': jsonEncode(responseBody()),
      'attendance_location_assignments_v1_cached_at': DateTime.now()
          .toUtc()
          .toIso8601String(),
    });
    final repository = AttendanceLocationAssignmentRepositoryImpl(
      client: AuthenticatedOperationClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
        tokenProvider: () async => 'token',
      ),
    );

    final snapshot = await repository.getMine();

    expect(snapshot.fromCache, isTrue);
    expect(snapshot.assignments.single.locationId, 'l1');
    expect(snapshot.isStale, isFalse);
  });

  test(
    'marks an old cache stale so check-in can require status check',
    () async {
      SharedPreferences.setMockInitialValues({
        'attendance_location_assignments_v1': jsonEncode(responseBody()),
        'attendance_location_assignments_v1_cached_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      });
      final repository = AttendanceLocationAssignmentRepositoryImpl(
        client: AuthenticatedOperationClient(
          client: MockClient(
            (_) async => throw http.ClientException('offline'),
          ),
          tokenProvider: () async => 'token',
        ),
      );

      final snapshot = await repository.getMine();

      expect(snapshot.fromCache, isTrue);
      expect(snapshot.isStale, isTrue);
    },
  );
}
