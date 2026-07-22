import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';
import '../models/leave_model.dart';
import '../models/permission_model.dart';
import '../models/advance_model.dart';
import '../utils/payroll_cycle.dart';

class RequestLogItem {
  final String id;
  final String employeeName;
  final String type; // 'leave' | 'permission' | 'advance'
  final String requestType;
  final String status;
  final DateTime reviewedAt;
  final String reviewedBy;
  final String details;
  final String reason;
  final String response;

  RequestLogItem({
    required this.id,
    required this.employeeName,
    required this.type,
    required this.requestType,
    required this.status,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.details,
    required this.reason,
    required this.response,
  });
}

class RequestLogService {
  RequestLogService._();
  static final RequestLogService instance = RequestLogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, String> _reviewerNameCache = {};

  String _reviewerLabel(Map<String, dynamic> data, String reviewerId) {
    final savedName = (data['reviewerName'] as String?)?.trim() ?? '';
    if (savedName.isNotEmpty) return savedName;

    final managerIds =
        (data['managerIds'] as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    final managerNames =
        (data['managerNames'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final managerIndex = managerIds.indexOf(reviewerId);
    if (managerIndex >= 0 && managerIndex < managerNames.length) {
      final name = managerNames[managerIndex].trim();
      if (name.isNotEmpty) return name;
    }
    if (data['hrReviewedBy'] == reviewerId) return 'الموارد البشرية';
    if (data['managerReviewedBy'] == reviewerId) return 'المدير المباشر';
    final cached = _reviewerNameCache[reviewerId];
    if (cached != null && cached.isNotEmpty) return cached;
    return reviewerId;
  }

  Future<void> _cacheReviewerNames(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final ids = docs
        .map((doc) => doc.data()['reviewedBy'] as String? ?? '')
        .where((id) => id.isNotEmpty && !_reviewerNameCache.containsKey(id))
        .toSet();
    await Future.wait(
      ids.map((id) async {
        final doc = await _db.collection('users').doc(id).get();
        final name = (doc.data()?['displayName'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) _reviewerNameCache[id] = name;
      }),
    );
  }

  Future<List<RequestLogItem>> getMonthlyLogs(UserModel user) async {
    final now = DateTime.now();
    final cycle = PayrollCycle.forDate(now);
    final cycleStart = Timestamp.fromDate(cycle.start);
    final cycleNextStart = Timestamp.fromDate(cycle.nextStart);

    final List<RequestLogItem> logs = [];

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> scopedDocs(
      String collection,
    ) async {
      if (user.role == EmployeeRole.manager) {
        final results = await Future.wait([
          _db
              .collection(collection)
              .where('managerIds', arrayContains: user.uid)
              .get(),
          _db
              .collection(collection)
              .where('managerId', isEqualTo: user.uid)
              .get(),
        ]);
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final doc in results.expand((snapshot) => snapshot.docs)) {
          final reviewedAt = (doc.data()['reviewedAt'] as Timestamp?)?.toDate();
          if (reviewedAt != null &&
              !reviewedAt.isBefore(cycle.start) &&
              reviewedAt.isBefore(cycle.nextStart)) {
            byId[doc.id] = doc;
          }
        }
        return byId.values.toList();
      }

      Query<Map<String, dynamic>> query = _db
          .collection(collection)
          .where('reviewedAt', isGreaterThanOrEqualTo: cycleStart)
          .where('reviewedAt', isLessThan: cycleNextStart);
      if (user.role == EmployeeRole.employee ||
          user.role == EmployeeRole.teamLeader) {
        query = query.where('userId', isEqualTo: user.uid);
      }
      return (await query.get()).docs;
    }

    // Query helper to fetch and parse
    Future<void> fetchLeaves() async {
      final docs = await scopedDocs('leaves');
      await _cacheReviewerNames(docs);
      for (final doc in docs) {
        final data = doc.data();
        final model = LeaveModel.fromFirestore(doc);
        if (model.status == 'approved' || model.status == 'rejected') {
          logs.add(
            RequestLogItem(
              id: model.leaveId,
              employeeName: model.employeeName,
              type: 'leave',
              requestType: _translateLeaveType(model.leaveType),
              status: model.status,
              reviewedAt: model.reviewedAt ?? now,
              reviewedBy: _reviewerLabel(data, model.reviewedBy ?? ''),
              details: '${model.numberOfDays} يوم',
              reason: model.reason ?? '',
              response: model.reviewerComment ?? '',
            ),
          );
        }
      }
    }

    Future<void> fetchPermissions() async {
      final docs = await scopedDocs('permissions');
      await _cacheReviewerNames(docs);
      for (final doc in docs) {
        final data = doc.data();
        final model = PermissionModel.fromFirestore(doc);
        if (model.status == 'approved' || model.status == 'rejected') {
          logs.add(
            RequestLogItem(
              id: model.permissionId,
              employeeName: model.employeeName,
              type: 'permission',
              requestType: _translatePermissionType(model.permissionType),
              status: model.status,
              reviewedAt: model.reviewedAt ?? now,
              reviewedBy: _reviewerLabel(data, model.reviewedBy ?? ''),
              details: '${model.durationMinutes} دقيقة',
              reason: model.reason,
              response: model.reviewerComment ?? '',
            ),
          );
        }
      }
    }

    Future<void> fetchAdvances() async {
      final docs = await scopedDocs('advances');
      await _cacheReviewerNames(docs);
      for (final doc in docs) {
        final data = doc.data();
        final model = AdvanceModel.fromFirestore(doc);
        if (model.status == 'approved' || model.status == 'rejected') {
          logs.add(
            RequestLogItem(
              id: model.advanceId,
              employeeName: model.employeeName,
              type: 'advance',
              requestType: 'سلفة مالية',
              status: model.status,
              reviewedAt: model.reviewedAt ?? now,
              reviewedBy: _reviewerLabel(data, model.reviewedBy ?? ''),
              details: '${model.amount} EGP',
              reason: model.reason ?? '',
              response: model.reviewerComment ?? '',
            ),
          );
        }
      }
    }

    await Future.wait([fetchLeaves(), fetchPermissions(), fetchAdvances()]);

    // Sort by reviewedAt descending
    logs.sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return logs;
  }

  String _translateLeaveType(String type) {
    switch (type) {
      case 'annual':
        return 'إجازة سنوية';
      case 'sick':
        return 'إجازة مرضية';
      case 'casual':
        return 'إجازة عارضة';
      case 'day_off':
        return 'مغادرة يوم';
      case 'unpaid':
        return 'إجازة بدون راتب';
      case 'exam':
        return 'إجازة امتحان';
      case 'wfh':
      case 'remote':
        return 'عمل عن بعد';
      default:
        return 'إجازة';
    }
  }

  String _translatePermissionType(String type) {
    switch (type) {
      case 'early_leave':
        return 'انصراف مبكر';
      case 'late_arrival':
        return 'تأخير صباحي';
      default:
        return 'إذن';
    }
  }
}
