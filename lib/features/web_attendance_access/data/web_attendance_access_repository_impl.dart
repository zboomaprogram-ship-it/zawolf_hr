import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/web_attendance_access_grant.dart';
import '../domain/repositories/web_attendance_access_repository.dart';

final class WebAttendanceAccessRepositoryImpl
    implements WebAttendanceAccessRepository {
  WebAttendanceAccessRepositoryImpl({
    required FirebaseFirestore firestore,
    required AuthenticatedOperationClient operations,
    required Uri baseUri,
  }) : _firestore = firestore,
       _operations = operations,
       _baseUri = baseUri;
  final FirebaseFirestore _firestore;
  final AuthenticatedOperationClient _operations;
  final Uri _baseUri;
  String _operationId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  Never _fail(AuthenticatedOperationResponse response) =>
      throw Exception('${response.data['error'] ?? 'تعذر تنفيذ العملية.'}');
  @override
  Future<WebAttendanceAccessGrant?> myActiveGrant() async {
    final response = await _operations.get(
      _baseUri.resolve('/attendance/web-access/me'),
    );
    if (!response.ok) _fail(response);
    if (response.data['eligible'] != true) return null;
    final raw = response.data['grant'];
    return raw is Map
        ? WebAttendanceAccessGrant.fromJson(raw.cast<String, Object?>())
        : null;
  }

  @override
  Future<List<WebAttendanceAccessGrant>> listGrants() async {
    final response = await _operations.get(
      _baseUri.resolve('/attendance/web-access/grants'),
    );
    if (!response.ok) _fail(response);
    final raw = response.data['grants'];
    return raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) =>
                  WebAttendanceAccessGrant.fromJson(e.cast<String, Object?>()),
            )
            .toList()
        : const [];
  }

  @override
  Future<List<WebAttendanceEmployee>> listActiveEmployees() async {
    final snapshot =
        await _firestore
            .collection('users')
            .where('isActive', isEqualTo: true)
            .limit(500)
            .get();
    final values =
        snapshot.docs.map((doc) {
          final d = doc.data();
          return WebAttendanceEmployee(
            id: doc.id,
            name: '${d['displayName'] ?? d['name'] ?? ''}',
            code: '${d['employeeId'] ?? d['employeeCode'] ?? ''}',
            position: '${d['position'] ?? d['jobTitle'] ?? ''}',
          );
        }).toList();
    values.sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  @override
  Future<void> saveGrant({
    required String employeeId,
    required String scope,
    bool allowAnyLocation = false,
    String? startDate,
    String? endDate,
    String? note,
  }) async {
    final response = await _operations.post(
      _baseUri.resolve('/attendance/web-access/grants'),
      operationId: _operationId(),
      body: {
        'employeeId': employeeId,
        'scope': scope,
        'allowAnyLocation': allowAnyLocation,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
      },
    );
    if (!response.ok) _fail(response);
  }

  @override
  Future<void> revokeGrant({required String employeeId, String? note}) async {
    final response = await _operations.post(
      _baseUri.resolve('/attendance/web-access/grants/$employeeId/revoke'),
      operationId: _operationId(),
      body: {if (note?.trim().isNotEmpty == true) 'note': note!.trim()},
    );
    if (!response.ok) _fail(response);
  }
}

WebAttendanceAccessRepositoryImpl createWebAttendanceAccessRepository({
  http.Client? client,
}) => WebAttendanceAccessRepositoryImpl(
  firestore: FirebaseFirestore.instance,
  operations: AuthenticatedOperationClient(
    client: client ?? http.Client(),
    tokenProvider:
        () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
  ),
  baseUri: Uri.parse('https://notification.zawolf.ai'),
);
