import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Small adapter for server-owned approval transitions.  The server validates
/// every stage; this class never writes route state to Firestore directly.
class RequestApprovalRoutingGateway {
  RequestApprovalRoutingGateway({http.Client? client})
    : _client = client ?? http.Client();

  static const _base = 'https://notification.zawolf.ai';
  final http.Client _client;
  final _random = Random.secure();

  String _operationId() =>
      List.generate(
        32,
        (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
      ).join();

  Future<Map<String, dynamic>> createFieldMission({
    required List<String> employeeUids,
    required List<Map<String, String>> approvers,
    required String missionDate,
    required String startTime,
    required String endTime,
    required String reason,
    String siteName = '',
    String locationId = '',
    bool requiresReturnToOffice = false,
    bool requiresCheckout = false,
  }) => _post('/operations/request-approval-routing/field-missions', {
    'operationId': _operationId(),
    'employeeUids': employeeUids,
    'approvers': approvers,
    'missionDate': missionDate,
    'startTime': startTime,
    'endTime': endTime,
    'reason': reason,
    'siteName': siteName,
    'locationId': locationId,
    'requiresReturnToOffice': requiresReturnToOffice,
    'requiresCheckout': requiresCheckout,
  });

  Future<Map<String, dynamic>> createEmployeeFieldMission({
    required String missionDate,
    required String startTime,
    required String endTime,
    required String reason,
    required String siteName,
    bool requiresReturnToOffice = false,
    bool requiresCheckout = false,
  }) => _post('/operations/request-approval-routing/employee-field-missions', {
    'operationId': _operationId(),
    'missionDate': missionDate,
    'startTime': startTime,
    'endTime': endTime,
    'reason': reason,
    'siteName': siteName,
    'requiresReturnToOffice': requiresReturnToOffice,
    'requiresCheckout': requiresCheckout,
  });

  Future<Map<String, dynamic>> decideFieldMission({
    required String requestId,
    required bool approved,
    String comment = '',
  }) => _post(
    '/operations/request-approval-routing/field-missions/$requestId/decision',
    {
      'operationId': _operationId(),
      'decision': approved ? 'approved' : 'rejected',
      'comment': comment,
    },
  );

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    Future<http.Response> send(bool forceRefresh) async {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(
        forceRefresh,
      );
      if (token == null || token.isEmpty) {
        throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
      }
      return _client.post(
        Uri.parse('$_base$path'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    }

    // An installed client can hold an expired Firebase token while the app is
    // foregrounded. Refresh once before reporting a route failure.
    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['ok'] != true) {
      throw StateError('${data['error'] ?? 'تعذر تنفيذ مسار الموافقة.'}');
    }
    return data;
  }
}
