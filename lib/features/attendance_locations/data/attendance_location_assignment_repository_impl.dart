import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/attendance_location_assignment.dart';
import '../domain/repositories/attendance_location_assignment_repository.dart';

final class AttendanceLocationAssignmentRepositoryImpl
    implements AttendanceLocationAssignmentRepository {
  AttendanceLocationAssignmentRepositoryImpl({
    AuthenticatedOperationClient? client,
    Future<SharedPreferences> Function()? preferences,
    this.baseUri = const String.fromEnvironment(
      'ATTENDANCE_API_BASE_URL',
      defaultValue: 'https://notification.zawolf.ai',
    ),
  }) : _client =
           client ??
           AuthenticatedOperationClient(
             client: http.Client(),
             tokenProvider: () async =>
                 FirebaseAuth.instance.currentUser?.getIdToken(),
           ),
       _preferences = preferences ?? SharedPreferences.getInstance;

  final AuthenticatedOperationClient _client;
  final Future<SharedPreferences> Function() _preferences;
  final String baseUri;
  static const _cacheKey = 'attendance_location_assignments_v1';
  static const _cacheTimeKey = 'attendance_location_assignments_v1_cached_at';
  static const _freshFor = Duration(hours: 24);

  @override
  Future<AttendanceLocationAssignmentsSnapshot> getMine({
    bool refresh = false,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUri/attendance/locations/assignments/me'),
    );
    if (response.ok) {
      final snapshot = _decode(response.data, fromCache: false);
      final preferences = await _preferences();
      await preferences.setString(_cacheKey, jsonEncode(response.data));
      await preferences.setString(
        _cacheTimeKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      return snapshot;
    }
    if (response.safeCode == 'session_expired') {
      throw StateError('انتهت جلسة الدخول. سجل الدخول مرة أخرى.');
    }
    final preferences = await _preferences();
    final cached = preferences.getString(_cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          final cachedAt = DateTime.tryParse(
            preferences.getString(_cacheTimeKey) ?? '',
          );
          final stale =
              cachedAt == null ||
              DateTime.now().toUtc().difference(cachedAt.toUtc()) > _freshFor;
          return _decode(
            Map<String, Object?>.from(decoded),
            fromCache: true,
            isStale: stale,
          );
        }
      } catch (_) {}
    }
    throw StateError(
      'تعذر تحميل مواقع الحضور المسندة. اتصل بالإنترنت ثم أعد المحاولة.',
    );
  }

  AttendanceLocationAssignmentsSnapshot _decode(
    Map<String, Object?> data, {
    required bool fromCache,
    bool isStale = false,
  }) {
    final rawAssignments = data['assignments'];
    final assignments = rawAssignments is List
        ? rawAssignments
              .whereType<Map>()
              .map((raw) {
                final item = Map<String, dynamic>.from(raw);
                return AttendanceLocationAssignment(
                  id: '${item['id'] ?? ''}',
                  employeeUid: '${item['employeeUid'] ?? ''}',
                  locationId: '${item['locationId'] ?? ''}',
                  locationName: '${item['locationName'] ?? ''}',
                  latitude: (item['latitude'] as num?)?.toDouble() ?? 0,
                  longitude: (item['longitude'] as num?)?.toDouble() ?? 0,
                  radiusMeters: (item['radiusMeters'] as num?)?.toDouble() ?? 0,
                  version: (item['version'] as num?)?.toInt() ?? 1,
                  priority: (item['priority'] as num?)?.toInt() ?? 0,
                  isDefault: item['isDefault'] == true,
                  isActive: item['isActive'] == true,
                  locationIsActive: item['locationIsActive'] != false,
                  effectiveFrom: DateTime.tryParse(
                    '${item['effectiveFrom'] ?? ''}',
                  ),
                  effectiveTo: DateTime.tryParse(
                    '${item['effectiveTo'] ?? ''}',
                  ),
                );
              })
              .toList(growable: false)
        : const <AttendanceLocationAssignment>[];
    return AttendanceLocationAssignmentsSnapshot(
      enabled: data['enabled'] == true,
      assignments: assignments,
      fromCache: fromCache,
      isStale: isStale,
    );
  }
}
