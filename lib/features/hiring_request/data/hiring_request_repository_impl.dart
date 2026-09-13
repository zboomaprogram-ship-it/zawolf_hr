import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/hiring_request_repository.dart';

class HiringRequestRepositoryImpl implements HiringRequestRepository {
  HiringRequestRepositoryImpl({http.Client? client})
    : _client = AuthenticatedOperationClient(
        client: client ?? http.Client(),
        tokenProvider:
            () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
      );
  final AuthenticatedOperationClient _client;
  final _random = Random.secure();
  String get _op =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  Uri get _uri =>
      Uri.parse('https://notification.zawolf.ai/operations/hiring-requests');
  Never _fail(AuthenticatedOperationResponse r) =>
      throw StateError('${r.data['error'] ?? 'تعذر تنفيذ العملية.'}');
  @override
  Future<List<HiringRequest>> list() async {
    final r = await _client.get(_uri);
    if (!r.ok) _fail(r);
    return (r.data['requests'] as List? ?? const []).whereType<Map>().map((e) {
      final d = Map<String, Object?>.from(e);
      return HiringRequest(
        id: '${d['id']}',
        name: '${d['proposedEmployeeName']}',
        jobTitle: '${d['jobTitle']}',
        status: '${d['status']}',
        currentApproverName: '${d['currentApproverName'] ?? ''}',
      );
    }).toList();
  }

  @override
  Future<void> create({
    required String name,
    required String jobTitle,
    required String managerId,
    required String managerName,
    required double salary,
    required String currency,
    required DateTime assignmentDate,
    String? existingEmployeeUid,
  }) async {
    final r = await _client.post(
      _uri,
      operationId: _op,
      body: {
        'proposedEmployeeName': name,
        'jobTitle': jobTitle,
        'managerId': managerId,
        'managerName': managerName,
        'baseMonthlySalary': salary,
        'salaryCurrency': currency,
        'assignmentDate':
            '${assignmentDate.year.toString().padLeft(4, '0')}-${assignmentDate.month.toString().padLeft(2, '0')}-${assignmentDate.day.toString().padLeft(2, '0')}',
        if (existingEmployeeUid?.isNotEmpty == true)
          'existingEmployeeUid': existingEmployeeUid,
      },
    );
    if (!r.ok) _fail(r);
  }

  @override
  Future<void> decide({
    required String id,
    required bool approved,
    String? comment,
  }) async {
    final r = await _client.post(
      _uri.resolve('/operations/hiring-requests/$id/decision'),
      operationId: _op,
      body: {
        'decision': approved ? 'approved' : 'rejected',
        if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
      },
    );
    if (!r.ok) _fail(r);
  }
}
