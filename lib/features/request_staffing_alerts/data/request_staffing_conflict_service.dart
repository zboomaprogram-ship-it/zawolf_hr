import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/leave_model.dart';
import '../../../models/permission_model.dart';
import '../../../services/role_notification_service.dart';
import '../domain/request_staffing_conflict.dart';

/// Advisory staffing signal. It never changes approval status or attendance.
class RequestStaffingConflictService {
  RequestStaffingConflictService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  static const _active = {
    'pending_manager',
    'pending_hr',
    'pending_ceo',
    'approved',
  };

  Future<List<RequestStaffingConflict>> forLeave(
    LeaveModel leave,
    String managerId,
  ) => _find(
    employeeId: leave.userId,
    managerId: managerId,
    title: awaitTitle(leave.userId),
    start: _date(leave.startDate),
    end: _date(leave.endDate),
  );
  Future<List<RequestStaffingConflict>> forPermission(
    PermissionModel permission,
    String managerId,
  ) => _find(
    employeeId: permission.userId,
    managerId: managerId,
    title: awaitTitle(permission.userId),
    start: permission.requestDate,
    end: permission.requestDate,
  );
  Future<String> awaitTitle(String employeeId) async {
    final user = await _db.collection('users').doc(employeeId).get();
    final data = user.data() ?? {};
    return normalizeStaffingJobTitle(
      '${data['position'] ?? data['jobTitle'] ?? ''}',
    );
  }

  Future<List<RequestStaffingConflict>> _find({
    required String employeeId,
    required String managerId,
    required Future<String> title,
    required String start,
    required String end,
  }) async {
    final normalized = await title;
    if (normalized.isEmpty || managerId.isEmpty) return const [];
    final results = <RequestStaffingConflict>[];
    final snapshots = await Future.wait([
      _db
          .collection('leaves')
          .where('managerId', isEqualTo: managerId)
          .limit(100)
          .get(),
      _db
          .collection('permissions')
          .where('managerId', isEqualTo: managerId)
          .limit(100)
          .get(),
    ]);
    for (final doc in snapshots[0].docs) {
      final d = doc.data();
      if (d['userId'] == employeeId || !_active.contains(d['status'])) continue;
      if (await _recordJobTitle(d) != normalized) {
        continue;
      }
      final otherStart = _timestampDate(d['startDate']);
      final otherEnd = _timestampDate(d['endDate']);
      if (otherStart.isNotEmpty &&
          otherEnd.isNotEmpty &&
          _onOrBefore(otherStart, end) &&
          _onOrBefore(start, otherEnd)) {
        results.add(
          RequestStaffingConflict(
            employeeName: '${d['employeeName'] ?? 'موظف'}',
            requestType: 'إجازة',
            date: '$start إلى $end',
          ),
        );
      }
    }
    for (final doc in snapshots[1].docs) {
      final d = doc.data();
      if (d['userId'] == employeeId || !_active.contains(d['status'])) continue;
      if (await _recordJobTitle(d) != normalized) {
        continue;
      }
      final date = '${d['requestDate'] ?? ''}';
      if (_onOrBefore(start, date) && _onOrBefore(date, end)) {
        results.add(
          RequestStaffingConflict(
            employeeName: '${d['employeeName'] ?? 'موظف'}',
            requestType: 'إذن',
            date: date,
          ),
        );
      }
    }
    return results;
  }

  Future<void> notifyManagerForLeave(
    LeaveModel leave, {
    required String managerId,
    required String jobTitle,
  }) => _notify(
    employeeId: leave.userId,
    employeeName: leave.employeeName,
    managerId: managerId,
    jobTitle: jobTitle,
    start: _date(leave.startDate),
    end: _date(leave.endDate),
    requestId: leave.leaveId,
    requestType: 'leave',
  );
  Future<void> notifyManagerForPermission(
    PermissionModel permission, {
    required String managerId,
    required String jobTitle,
  }) => _notify(
    employeeId: permission.userId,
    employeeName: permission.employeeName,
    managerId: managerId,
    jobTitle: jobTitle,
    start: permission.requestDate,
    end: permission.requestDate,
    requestId: permission.permissionId,
    requestType: 'permission',
  );
  Future<void> _notify({
    required String employeeId,
    required String employeeName,
    required String managerId,
    required String jobTitle,
    required String start,
    required String end,
    required String requestId,
    required String requestType,
  }) async {
    final conflicts = await _find(
      employeeId: employeeId,
      managerId: managerId,
      title: Future.value(normalizeStaffingJobTitle(jobTitle)),
      start: start,
      end: end,
    );
    if (conflicts.isEmpty) return;
    final first = conflicts.first;
    await RoleNotificationService.instance.createNotification(
      recipientId: managerId,
      type: 'staffing_same_title_overlap',
      title: 'تنبيه تغطية الفريق',
      body:
          '$employeeName و${first.employeeName} لديهما طلبات متداخلة للمسمى الوظيفي نفسه في ${first.date}.',
      data: {
        'requestId': requestId,
        'requestType': requestType,
        'route': '/manager/requests',
      },
      eventId: 'staffing:$managerId:$requestId:${first.date}',
    );
  }

  Future<String> _recordJobTitle(Map<String, dynamic> data) async {
    final stored = normalizeStaffingJobTitle('${data['jobTitle'] ?? ''}');
    if (stored.isNotEmpty) return stored;
    final employeeId = '${data['userId'] ?? ''}'.trim();
    if (employeeId.isEmpty) return '';
    return awaitTitle(employeeId);
  }

  static bool _onOrBefore(String first, String second) =>
      first.compareTo(second) <= 0;

  static String _timestampDate(dynamic value) {
    if (value is Timestamp) return _date(value.toDate());
    return '';
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
