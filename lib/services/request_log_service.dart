import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';
import '../models/leave_model.dart';
import '../models/permission_model.dart';
import '../models/advance_model.dart';

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
  });
}

class RequestLogService {
  RequestLogService._();
  static final RequestLogService instance = RequestLogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<RequestLogItem>> getMonthlyLogs(UserModel user) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final List<RequestLogItem> logs = [];

    // Query helper to fetch and parse
    Future<void> fetchLeaves() async {
      Query query = _db
          .collection('leaves')
          .where(
            'reviewedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          );

      if (user.role == EmployeeRole.employee ||
          user.role == EmployeeRole.teamLeader) {
        query = query.where('userId', isEqualTo: user.uid);
      } else if (user.role == EmployeeRole.manager) {
        query = query.where('managerId', isEqualTo: user.uid);
      }

      final snap = await query.get();
      for (final doc in snap.docs) {
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
              reviewedBy: model.reviewedBy ?? '',
              details: '${model.numberOfDays} يوم',
              reason: model.reason ?? '',
            ),
          );
        }
      }
    }

    Future<void> fetchPermissions() async {
      Query query = _db
          .collection('permissions')
          .where(
            'reviewedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          );

      if (user.role == EmployeeRole.employee ||
          user.role == EmployeeRole.teamLeader) {
        query = query.where('userId', isEqualTo: user.uid);
      } else if (user.role == EmployeeRole.manager) {
        query = query.where('managerId', isEqualTo: user.uid);
      }

      final snap = await query.get();
      for (final doc in snap.docs) {
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
              reviewedBy: model.reviewedBy ?? '',
              details: '${model.durationMinutes} دقيقة',
              reason: model.reason,
            ),
          );
        }
      }
    }

    Future<void> fetchAdvances() async {
      Query query = _db
          .collection('advances')
          .where(
            'reviewedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          );

      if (user.role == EmployeeRole.employee ||
          user.role == EmployeeRole.teamLeader) {
        query = query.where('userId', isEqualTo: user.uid);
      } else if (user.role == EmployeeRole.manager) {
        query = query.where('managerId', isEqualTo: user.uid);
      }

      final snap = await query.get();
      for (final doc in snap.docs) {
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
              reviewedBy: model.reviewedBy ?? '',
              details: '${model.amount} EGP',
              reason: model.reason ?? '',
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
