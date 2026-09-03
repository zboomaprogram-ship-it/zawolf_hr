import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/configurable_requests_repository.dart';

class ConfigurableRequestsRepositoryImpl
    implements ConfigurableRequestsRepository {
  ConfigurableRequestsRepositoryImpl({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();
  static const _base = 'https://notification.zawolf.ai';
  final FirebaseAuth _auth;
  final http.Client _client;
  final _random = Random.secure();
  String get _operationId =>
      List.generate(
        32,
        (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
      ).join();

  Future<Map<String, dynamic>> _call(
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty)
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    final response =
        body == null
            ? await _client.get(
              Uri.parse('$_base$path'),
              headers: {'authorization': 'Bearer $token'},
            )
            : await _client.post(
              Uri.parse('$_base$path'),
              headers: {
                'authorization': 'Bearer $token',
                'content-type': 'application/json',
              },
              body: jsonEncode({...body, 'operationId': _operationId}),
            );
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['ok'] != true)
      throw StateError('${data['error'] ?? 'تعذر تنفيذ الطلب الآن.'}');
    return data;
  }

  @override
  Future<List<CustomRequestType>> types() async =>
      ((await _call('/operations/custom-request-types'))['types'] as List? ??
              const [])
          .whereType<Map>()
          .map((raw) {
            final value = Map<String, dynamic>.from(raw);
            return CustomRequestType(
              id: '${value['id']}',
              name: '${value['nameAr'] ?? ''}',
              description: '${value['descriptionAr'] ?? ''}',
              fields:
                  (value['fields'] as List? ?? const [])
                      .whereType<Map>()
                      .map(Map<String, dynamic>.from)
                      .toList(),
            );
          })
          .toList();

  @override
  Future<List<CustomRequestDirectoryUser>> directory() async =>
      ((await _call('/operations/custom-request-directory'))['users']
                  as List? ??
              const [])
          .whereType<Map>()
          .map(
            (raw) => CustomRequestDirectoryUser(
              id: '${raw['id']}',
              name: '${raw['name']}',
              department: '${raw['department'] ?? ''}',
              role: '${raw['role'] ?? ''}',
            ),
          )
          .toList();

  @override
  Future<void> saveType({
    required String name,
    required String description,
    required List<String> approverIds,
    required bool allActive,
    required List<String> employeeIds,
    required List<Map<String, Object?>> fields,
  }) => _call(
    '/operations/custom-request-types',
    body: {
      'nameAr': name,
      'descriptionAr': description,
      'approverIds': approverIds,
      'audience': {'allActive': allActive, 'employeeIds': employeeIds},
      'fields': fields,
    },
  );

  @override
  Future<void> submit({
    required String typeId,
    required String description,
    required Map<String, String> answers,
  }) => _call(
    '/operations/custom-requests',
    body: {'typeId': typeId, 'description': description, 'answers': answers},
  );

  @override
  Future<void> submitDirect({
    required String title,
    required String description,
    required List<String> approverIds,
    String? attachmentUrl,
  }) => _call(
    '/operations/custom-requests',
    body: {
      'title': title,
      'description': description,
      'approverIds': approverIds,
      'attachmentUrl': attachmentUrl,
    },
  );

  @override
  Future<List<Map<String, dynamic>>> requests({required bool queue}) async =>
      ((await _call('/operations/custom-requests?queue=$queue'))['requests']
                  as List? ??
              const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

  @override
  Future<void> decide({
    required String id,
    required bool approved,
    String comment = '',
  }) => _call(
    '/operations/custom-requests/$id/decision',
    body: {'decision': approved ? 'approved' : 'rejected', 'comment': comment},
  );
}
