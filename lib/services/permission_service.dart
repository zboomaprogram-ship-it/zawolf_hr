import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/user_model.dart';
import '../models/permission_model.dart';
import '../models/attendance_policy.dart';
import 'audit_log_service.dart';
import 'attendance_policy_service.dart';

class PermissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AttendancePolicyService _policyService = AttendancePolicyService();

  DateTime _parseTimeToday(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime _parseExpectedTimeToday(String timeStr) {
    return _parseTimeToday(timeStr);
  }

  // Submit permission request with rule audits
  Future<void> submitPermission(PermissionModel req, UserModel employee) async {
    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);
    final policyConfig = await _policyService.getPolicyConfig();

    // ── Rule 1: Validate quota (maximum 2 permissions OR 5 hours total) ──
    final monthlyDocs = await _db
        .collection('permissions')
        .where('userId', isEqualTo: req.userId)
        .where('monthKey', isEqualTo: monthKey)
        .where('status', whereIn: ['approved', 'pending_hr', 'pending_manager'])
        .get();

    final usedCount = monthlyDocs.docs.length;
    final usedHours = monthlyDocs.docs.fold<double>(
      0.0,
      (total, doc) =>
          total + (doc.data()['durationMinutes'] as num? ?? 0) / 60.0,
    );

    final newHours = req.durationMinutes / 60.0;
    final isExceedingQuota = usedCount >= 2 || (usedHours + newHours) > 5.0;

    // ── Rule 2: Late arrival request must be submitted before work start ──
    bool isLateSubmission = false;
    if (req.permissionType == 'late_arrival') {
      final workStartStr =
          employee.workSchedule.startTime ?? policyConfig.defaultStartTime;
      final workStart = _parseTimeToday(workStartStr);
      isLateSubmission = now.isAfter(workStart);
    }

    final deduction = req.permissionType == 'late_arrival'
        ? policyConfig.evaluateLateArrival(
            arrivalTime: _parseExpectedTimeToday(req.expectedTime),
            employeeStartTime:
                employee.workSchedule.startTime ??
                policyConfig.defaultStartTime,
          )
        : const AttendanceDeduction(
            dayFraction: 0,
            code: 'none',
            arabicLabel: 'لا يوجد خصم',
            status: 'present',
            isLate: false,
            lateMinutes: 0,
          );
    final salaryDeductionAmount = policyConfig.calculateSalaryDeductionAmount(
      monthlySalary: employee.baseMonthlySalary,
      dayFraction: deduction.dayFraction,
    );

    final permRef = _db.collection('permissions').doc();
    final finalStatus = isLateSubmission ? 'invalid_late' : 'pending_hr';

    final finalModel = PermissionModel(
      permissionId: permRef.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      permissionType: req.permissionType,
      requestDate: req.requestDate,
      expectedTime: req.expectedTime,
      durationMinutes: req.durationMinutes,
      reason: req.reason,
      status: finalStatus,
      isExceedingQuota: isExceedingQuota,
      isSubmittedAfterWorkStart: isLateSubmission,
      salaryDeductionFraction: deduction.dayFraction,
      salaryDeductionAmount: salaryDeductionAmount,
      salaryCurrency: employee.salaryCurrency,
      salaryDeductionCode: deduction.code,
      salaryDeductionLabel: deduction.arabicLabel,
      monthKey: monthKey,
      submittedAt: now,
      isRead: false,
    );

    await permRef.set(finalModel.toFirestore());

    // ── Triggers notifications (No functions, direct Firestore write) ──
    if (isLateSubmission) {
      // Notify employee of auto-rejection
      try {
        await _createNotification(
          recipientId: req.userId,
          type: 'permission_invalid_late',
          title: 'طلب إذن غير مقبول ❌',
          body:
              'لا يُعتد بطلب تأخير الحضور المقدَّم بعد بداية وقت العمل الرسمي وفق اللائحة.',
        );
      } catch (_) {}
    } else {
      await _notifyRole(
        role: 'hr_admin',
        type: 'permission_pending_hr',
        title: 'طلب إذن بانتظار HR',
        body:
            '${req.employeeName} يطلب إذن ${req.permissionType == 'late_arrival' ? 'تأخير حضور' : 'مغادرة مبكرة'}.'
            '${isExceedingQuota ? " (تجاوز الحد الشهري)" : ""}',
        data: {'permissionId': permRef.id},
      );
    }
  }

  // HR approves first, then manager gives final approval.
  Future<void> approvePermission(String permissionId, String reviewerId) async {
    final docRef = _db.collection('permissions').doc(permissionId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإذن غير موجود');
    final perm = PermissionModel.fromFirestore(doc);

    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerRole = (reviewerDoc.data()?['role'] as String?) ?? 'employee';

    if (perm.status == 'pending_hr') {
      await docRef.update({
        'status': 'pending_manager',
        'hrReviewedBy': reviewerId,
        'hrReviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      await AuditLogService.instance.record(
        actorId: reviewerId,
        action: 'permission_hr_approved',
        targetCollection: 'permissions',
        targetId: permissionId,
        metadata: {'userId': perm.userId, 'managerId': perm.managerId},
      );

      if (perm.managerId.isNotEmpty) {
        try {
          await _createNotification(
            recipientId: perm.managerId,
            type: 'permission_pending_manager',
            title: 'طلب إذن بانتظار موافقتك',
            body:
                '${perm.employeeName} حصل على موافقة HR وينتظر قرارك النهائي.',
            data: {'permissionId': permissionId},
          );
        } catch (_) {}
      }
      return;
    }

    if (perm.status != 'pending_manager') {
      throw Exception('طلب الإذن ليس في مرحلة موافقة المدير.');
    }

    if (reviewerRole != 'manager' && reviewerRole != 'super_admin') {
      throw Exception('هذا الطلب ينتظر موافقة المدير.');
    }

    final batch = _db.batch();

    // 1. Update status
    batch.update(docRef, {
      'status': 'approved',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'managerReviewedBy': reviewerId,
      'managerReviewedAt': FieldValue.serverTimestamp(),
    });

    // 2. Increment employee quota counters
    final userRef = _db.collection('users').doc(perm.userId);
    batch.update(userRef, {
      'permissionBalance.usedThisMonth': FieldValue.increment(1),
      'permissionBalance.usedHoursThisMonth': FieldValue.increment(
        perm.durationMinutes / 60.0,
      ),
    });

    await batch.commit();

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'permission_manager_approved',
      targetCollection: 'permissions',
      targetId: permissionId,
      metadata: {
        'userId': perm.userId,
        'durationMinutes': perm.durationMinutes,
        'permissionType': perm.permissionType,
      },
    );

    // 3. Notify employee
    try {
      await _createNotification(
        recipientId: perm.userId,
        type: 'permission_approved',
        title: 'تم قبول طلب الإذن ✅',
        body: 'تمت موافقة HR والمدير على طلب إذنك ليوم ${perm.requestDate}.',
      );
    } catch (_) {}
  }

  // Manager/HR rejects permission
  Future<void> rejectPermission(
    String permissionId,
    String reviewerId,
    String comment,
  ) async {
    final docRef = _db.collection('permissions').doc(permissionId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإذن غير موجود');
    final perm = PermissionModel.fromFirestore(doc);

    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerRole = (reviewerDoc.data()?['role'] as String?) ?? 'employee';
    final isHrStage = perm.status == 'pending_hr';

    await docRef.update({
      'status': 'rejected',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerComment': comment,
      if (isHrStage) 'hrReviewedBy': reviewerId,
      if (isHrStage) 'hrReviewedAt': FieldValue.serverTimestamp(),
      if (isHrStage) 'hrReviewerComment': comment,
      if (!isHrStage &&
          (reviewerRole == 'manager' || reviewerRole == 'super_admin'))
        'managerReviewedBy': reviewerId,
      if (!isHrStage &&
          (reviewerRole == 'manager' || reviewerRole == 'super_admin'))
        'managerReviewedAt': FieldValue.serverTimestamp(),
      if (!isHrStage &&
          (reviewerRole == 'manager' || reviewerRole == 'super_admin'))
        'managerReviewerComment': comment,
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'permission_rejected',
      targetCollection: 'permissions',
      targetId: permissionId,
      metadata: {'userId': perm.userId, 'permissionType': perm.permissionType},
    );

    // Notify employee
    try {
      await _createNotification(
        recipientId: perm.userId,
        type: 'permission_rejected',
        title: 'تم رفض طلب الإذن ❌',
        body:
            'تم رفض طلب إذنك ليوم ${perm.requestDate} من ${isHrStage ? "HR" : "المدير"}. السبب: $comment',
      );
    } catch (_) {}
  }

  // Reset monthly balance client-side
  Future<void> checkAndResetMonthlyPermissionQuota(UserModel user) async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    if (user.permissionBalance.lastResetMonth != currentMonth) {
      await _db.collection('users').doc(user.uid).update({
        'permissionBalance.usedThisMonth': 0,
        'permissionBalance.usedHoursThisMonth': 0.0,
        'permissionBalance.lastResetMonth': currentMonth,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Private Helper to create notification records
  Future<void> _createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final notifRef = _db
        .collection('notifications')
        .doc(recipientId)
        .collection('items')
        .doc();

    await notifRef.set({
      'notificationId': notifRef.id,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }

  Future<void> _notifyRole({
    required String role,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final targets = <String>{};
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      targets.addAll(snap.docs.map((doc) => doc.id));
      final superSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'super_admin')
          .get();
      targets.addAll(superSnap.docs.map((doc) => doc.id));

      for (final userId in targets) {
        await _createNotification(
          recipientId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (_) {
      // Notification delivery must not block the permission request flow.
    }
  }
}
