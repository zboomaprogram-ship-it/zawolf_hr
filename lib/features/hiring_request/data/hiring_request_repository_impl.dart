import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/hiring_request_repository.dart';

class HiringRequestRepositoryImpl implements HiringRequestRepository {
  HiringRequestRepositoryImpl({http.Client? client, FirebaseFirestore? firestore})
    : _client = AuthenticatedOperationClient(
        client: client ?? http.Client(),
        tokenProvider:
            () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
      ),
      _db = firestore ?? FirebaseFirestore.instance;
  final AuthenticatedOperationClient _client;
  final FirebaseFirestore _db;
  final _random = Random.secure();
  String get _op =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
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
  Future<List<HiringManagerOption>> getManagers() async {
    try {
      final snap = await _db.collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      final list = <HiringManagerOption>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final role = (d['role'] as String? ?? '').toLowerCase();
        final dept = (d['department'] as String? ?? d['departmentName'] as String? ?? '').trim();
        final pos = (d['position'] as String? ?? d['jobTitle'] as String? ?? '').trim();
        final roleText = '$role $dept $pos'.toLowerCase();
        final isMgr = ['manager', 'team_leader', 'hr_manager', 'super_admin'].contains(role) ||
            roleText.contains('manager') ||
            roleText.contains('مدير') ||
            d['isManager'] == true;

        if (isMgr) {
          final name = (d['displayName'] ?? d['name'] ?? '').toString().trim();
          final empId = (d['employeeId'] ?? d['employeeCode'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            list.add(HiringManagerOption(
              id: doc.id,
              name: name,
              employeeId: empId,
              department: dept,
            ));
          }
        }
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<String>> getJobTitles() async {
    try {
      final snap = await _db.collection('job_titles').orderBy('name').get();
      final titles = snap.docs
          .map((d) => (d.data()['name'] as String? ?? '').trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      if (titles.isEmpty) {
        titles.addAll(const [
          'Account Manager',
          'Auditor',
          'Content Creator',
          'Customer Manager',
          'Financial Officer',
          'General Manager',
          'Graphic Designer',
          'Media Buyer',
          'Mobile Developer',
          'Motion Graphics Artist',
          'Sales Manager',
          'SEO Specialist',
          'Software Manager',
          'System Analyst',
          'Tele Sales',
          'UI Designer',
          'Video Editor',
          'Web Developer',
        ]);
      }
      titles.sort();
      return titles;
    } catch (_) {
      return const [
        'Account Manager',
        'Financial Officer',
        'Mobile Developer',
        'Sales Manager',
        'Tele Sales',
        'Web Developer',
      ];
    }
  }

  @override
  Future<List<HiringEmployeeOption>> getEmployees() async {
    try {
      final snap = await _db.collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      final list = <HiringEmployeeOption>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final name = (d['displayName'] ?? d['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          list.add(HiringEmployeeOption(
            id: doc.id,
            name: name,
            employeeId: (d['employeeId'] ?? d['employeeCode'] ?? '').toString().trim(),
            department: (d['department'] ?? d['departmentName'] ?? '').toString().trim(),
            jobTitle: (d['position'] ?? d['jobTitle'] ?? '').toString().trim(),
          ));
        }
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return const [];
    }
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
