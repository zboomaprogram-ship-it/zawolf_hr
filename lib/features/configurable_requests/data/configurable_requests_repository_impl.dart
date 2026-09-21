import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/configurable_requests_repository.dart';

class ConfigurableRequestsRepositoryImpl
    implements ConfigurableRequestsRepository {
  ConfigurableRequestsRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();
  static const _base = 'https://notification.zawolf.ai';
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
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
    if (token == null || token.isEmpty) {
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    }
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
        data['ok'] != true) {
      throw StateError('${data['error'] ?? 'تعذر تنفيذ الطلب الآن.'}');
    }
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
  Future<List<CustomRequestDirectoryUser>> directory() async {
    try {
      final res = await _call('/operations/custom-request-directory');
      final usersRaw = res['users'] as List? ?? const [];
      if (usersRaw.isNotEmpty) {
        return usersRaw
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
      }
    } catch (_) {}

    try {
      final snap = await _firestore.collection('users').limit(300).get();
      final list = <CustomRequestDirectoryUser>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false || data['disabled'] == true) continue;
        final name = (data['displayName'] ??
                data['name'] ??
                data['employeeName'] ??
                data['email'] ??
                '')
            .toString()
            .trim();
        if (name.isEmpty) continue;
        list.add(
          CustomRequestDirectoryUser(
            id: doc.id,
            name: name,
            department: (data['department'] ??
                    data['departmentName'] ??
                    data['locationName'] ??
                    'العامة')
                .toString()
                .trim(),
            role: (data['role'] ?? 'موظف').toString().trim(),
          ),
        );
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return const [];
    }
  }

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
  }) async {
    try {
      await _call(
        '/operations/custom-requests',
        body: {
          'title': title,
          'description': description,
          'approverIds': approverIds,
          'attachmentUrl': attachmentUrl,
        },
      );
      return;
    } catch (e) {
      final user = _auth.currentUser;
      if (user == null) rethrow;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final requesterName = (userData['displayName'] ??
              userData['name'] ??
              userData['employeeName'] ??
              user.displayName ??
              'مسؤول HR')
          .toString();

      final route = <Map<String, dynamic>>[];
      for (var i = 0; i < approverIds.length; i++) {
        final approverId = approverIds[i];
        final appDoc =
            await _firestore.collection('users').doc(approverId).get();
        final appData = appDoc.data() ?? {};
        final appName = (appData['displayName'] ??
                appData['name'] ??
                appData['employeeName'] ??
                'مسؤول')
            .toString();
        route.add({
          'stageId': 'custom:${i + 1}',
          'order': i + 1,
          'approverId': approverId,
          'approverName': appName,
          'state': i == 0 ? 'pending' : 'waiting',
        });
      }

      await _firestore.collection('customRequests').add({
        'requesterId': user.uid,
        'requesterName': requesterName,
        'typeId': 'direct',
        'typeNameAr': 'طلب مخصص',
        'title': title.trim().isEmpty ? 'طلب مخصص' : title.trim(),
        'description': description.trim(),
        if (attachmentUrl != null && attachmentUrl.trim().isNotEmpty)
          'attachmentUrl': attachmentUrl.trim(),
        'status': 'pending',
        'approvalRoute': route,
        'currentApproverId': route.isNotEmpty ? route[0]['approverId'] : '',
        'currentApprovalIndex': 0,
        'approvalHistory': [
          {
            'action': 'submitted',
            'actorId': user.uid,
            'actorName': requesterName,
            'at': DateTime.now().toUtc().toIso8601String(),
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<List<Map<String, dynamic>>> requests({required bool queue}) async {
    try {
      final res = await _call('/operations/custom-requests?queue=$queue');
      final list = res['requests'] as List? ?? const [];
      return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {
      final user = _auth.currentUser;
      if (user == null) return const [];
      try {
        Query<Map<String, dynamic>> q = _firestore.collection('customRequests');
        if (queue) {
          q = q
              .where('currentApproverId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'pending');
        } else {
          q = q.where('requesterId', isEqualTo: user.uid);
        }
        final snap = await q.limit(100).get();
        return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  @override
  Future<void> decide({
    required String id,
    required bool approved,
    String comment = '',
  }) async {
    try {
      await _call(
        '/operations/custom-requests/$id/decision',
        body: {
          'decision': approved ? 'approved' : 'rejected',
          'comment': comment,
        },
      );
      return;
    } catch (e) {
      final user = _auth.currentUser;
      if (user == null) rethrow;
      final ref = _firestore.collection('customRequests').doc(id);
      final snap = await ref.get();
      if (!snap.exists) rethrow;
      final data = snap.data() ?? {};
      final route = (data['approvalRoute'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final currentIndex = (data['currentApprovalIndex'] as num?)?.toInt() ?? 0;
      if (currentIndex < route.length) {
        route[currentIndex]['state'] = approved ? 'approved' : 'rejected';
        route[currentIndex]['actedAt'] =
            DateTime.now().toUtc().toIso8601String();
        route[currentIndex]['comment'] = comment.trim();
      }
      final nextIndex = approved ? currentIndex + 1 : currentIndex;
      final nextApproverId = (approved && nextIndex < route.length)
          ? '${route[nextIndex]['approverId']}'
          : '';
      final newStatus = !approved
          ? 'rejected'
          : (nextIndex >= route.length ? 'approved' : 'pending');

      await ref.update({
        'approvalRoute': route,
        'currentApprovalIndex': nextIndex,
        'currentApproverId': nextApproverId,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
