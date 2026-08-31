import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/repositories/attendance_location_assignment_repository.dart';

final class AttendanceLocationAdministrationRepositoryImpl
    implements AttendanceLocationAdministrationRepository {
  AttendanceLocationAdministrationRepositoryImpl({
    AuthenticatedOperationClient? client,
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
           );

  final AuthenticatedOperationClient _client;
  final String baseUri;

  Map<String, Object?> _payload({
    required List<String> employeeUids,
    required List<String> locationIds,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  }) => {
    'employeeUids': employeeUids,
    'locationIds': locationIds,
    if (effectiveFrom != null)
      'effectiveFrom': effectiveFrom.toUtc().toIso8601String(),
    if (effectiveTo != null)
      'effectiveTo': effectiveTo.toUtc().toIso8601String(),
    if (defaultLocationId != null) 'defaultLocationId': defaultLocationId,
    'mode': remove ? 'remove' : 'assign',
  };

  @override
  Future<Map<String, dynamic>> previewAssignments({
    required List<String> employeeUids,
    required List<String> locationIds,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUri/attendance/locations/assignments/preview'),
      operationId:
          'attendance-location-preview-${DateTime.now().microsecondsSinceEpoch}',
      body: _payload(
        employeeUids: employeeUids,
        locationIds: locationIds,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        defaultLocationId: defaultLocationId,
        remove: remove,
      ),
    );
    return _requireSuccess(response);
  }

  @override
  Future<Map<String, dynamic>> applyAssignments({
    required String operationId,
    required String previewToken,
    required List<String> employeeUids,
    required List<String> locationIds,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUri/attendance/locations/assignments/apply'),
      operationId: operationId,
      body: {
        ..._payload(
          employeeUids: employeeUids,
          locationIds: locationIds,
          effectiveFrom: effectiveFrom,
          effectiveTo: effectiveTo,
          defaultLocationId: defaultLocationId,
          remove: remove,
        ),
        'previewToken': previewToken,
      },
    );
    return _requireSuccess(response);
  }

  Map<String, dynamic> _requireSuccess(
    AuthenticatedOperationResponse response,
  ) {
    if (response.ok) return Map<String, dynamic>.from(response.data);
    const messages = {
      'session_expired': 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
      'not_authorized': 'لا تملك صلاحية إدارة مواقع حضور الموظفين.',
      'preview_changed': 'تغيرت البيانات. أعد المعاينة قبل الحفظ.',
      'capacity_reached':
          'العملية أكبر من الحد الآمن. قلّل عدد الموظفين أو المواقع.',
      'connection_interrupted':
          'تعذر الاتصال بالخدمة. تحقق من الإنترنت ثم أعد المحاولة.',
    };
    throw StateError(
      messages[response.safeCode] ??
          'تعذر حفظ إسنادات المواقع الآن. أعد المحاولة.',
    );
  }
}
