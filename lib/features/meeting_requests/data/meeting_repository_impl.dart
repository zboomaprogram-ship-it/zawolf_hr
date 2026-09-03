import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/meeting_repository.dart';

class MeetingRepositoryImpl implements MeetingRepository {
  MeetingRepositoryImpl({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  static const _base = 'https://notification.zawolf.ai';
  final FirebaseAuth _auth;
  final http.Client _client;
  final Random _random = Random.secure();

  String _operationId() =>
      List.generate(
        32,
        (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
      ).join();

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    String method = 'POST',
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    }
    final response =
        body == null
            ? await _client.get(
              Uri.parse('$_base$path'),
              headers: {'Authorization': 'Bearer $token'},
            )
            : await _sendJson(Uri.parse('$_base$path'), token, body, method);
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['ok'] != true) {
      throw StateError('${data['error'] ?? 'تعذر تنفيذ طلب الاجتماع.'}');
    }
    return data;
  }

  Future<http.Response> _sendJson(
    Uri uri,
    String token,
    Map<String, dynamic> body,
    String method,
  ) async {
    if (method == 'POST') {
      return _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }
    final request =
        http.Request(method, uri)
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'content-type': 'application/json',
          })
          ..body = jsonEncode(body);
    return http.Response.fromStream(await _client.send(request));
  }

  @override
  Future<List<MeetingRoom>> rooms() async {
    final data = await _request('/operations/meeting-rooms');
    return (data['rooms'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => MeetingRoom(
            id: '${item['id']}',
            name: '${item['nameAr'] ?? ''}',
            description: '${item['descriptionAr'] ?? ''}',
            capacity: (item['capacity'] as num?)?.toInt() ?? 0,
            isActive: item['isActive'] != false,
          ),
        )
        .toList();
  }

  @override
  Future<List<MeetingApprover>> approvers() async {
    final data = await _request('/operations/meeting-approvers');
    return (data['approvers'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => MeetingApprover(
            id: '${item['id']}',
            name: '${item['name']}',
            roleLabel: '${item['roleLabel']}',
          ),
        )
        .toList();
  }

  @override
  Future<bool> isAvailable({
    required String roomId,
    required DateTime start,
    required DateTime end,
  }) async {
    final data = await _request(
      '/operations/meeting-availability?roomId=$roomId&startAt=${Uri.encodeComponent(start.toIso8601String())}&endAt=${Uri.encodeComponent(end.toIso8601String())}',
    );
    return data['available'] == true;
  }

  @override
  Future<void> create({
    required String managerId,
    required String roomId,
    required DateTime start,
    required DateTime end,
    required String purpose,
  }) => _request(
    '/operations/meeting-requests',
    body: {
      'operationId': _operationId(),
      'managerId': managerId,
      'roomId': roomId,
      'startAt': start.toIso8601String(),
      'endAt': end.toIso8601String(),
      'purpose': purpose,
    },
  );

  @override
  Future<void> saveRoom({
    required String name,
    String description = '',
    int? capacity,
    String? roomId,
    bool isActive = true,
  }) => _request(
    roomId == null
        ? '/operations/meeting-rooms'
        : '/operations/meeting-rooms/$roomId',
    method: roomId == null ? 'POST' : 'PATCH',
    body: {
      'operationId': _operationId(),
      'nameAr': name,
      'descriptionAr': description,
      if (capacity != null) 'capacity': capacity,
      'isActive': isActive,
    },
  );

  @override
  Future<List<MeetingRequest>> requests({required bool approvalQueue}) async {
    final data = await _request(
      '/operations/meeting-requests?queue=$approvalQueue',
    );
    return (data['requests'] as List? ?? const []).whereType<Map>().map((item) {
      final raw = Map<String, dynamic>.from(item);
      return MeetingRequest(
        id: '${raw['id']}',
        requesterName: '${raw['requesterName'] ?? ''}',
        approverName: '${raw['managerName'] ?? ''}',
        roomName: '${raw['roomName'] ?? ''}',
        purpose: '${raw['purpose'] ?? ''}',
        status: '${raw['status'] ?? 'pending'}',
        startAt: DateTime.tryParse('${raw['startAt'] ?? ''}'),
        endAt: DateTime.tryParse('${raw['endAt'] ?? ''}'),
        approvalRoute:
            (raw['approvalRoute'] as List? ?? const [])
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList(),
      );
    }).toList();
  }

  @override
  Future<void> decide({
    required String requestId,
    required bool approved,
    String comment = '',
  }) => _request(
    '/operations/meeting-requests/$requestId/decision',
    body: {
      'operationId': _operationId(),
      'decision': approved ? 'approved' : 'rejected',
      'comment': comment,
    },
  );

  @override
  Future<void> cancel(String requestId) => _request(
    '/operations/meeting-requests/$requestId/cancel',
    body: {'operationId': _operationId()},
  );
}
