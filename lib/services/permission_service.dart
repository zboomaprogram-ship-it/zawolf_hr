import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/permission_model.dart';
import '../models/attendance_policy.dart';
import '../models/employee_role.dart';
import '../models/manager_approval_chain.dart';
import 'audit_log_service.dart';
import 'attendance_policy_service.dart';
import 'request_approval_policy_service.dart';
import 'role_notification_service.dart';
import 'attendance_reconciliation_service.dart';
import '../utils/payroll_cycle.dart';

class PermissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AttendancePolicyService _policyService = AttendancePolicyService();
  final RequestApprovalPolicyService _approvalPolicyService =
      RequestApprovalPolicyService();
  final AttendanceReconciliationService _reconciliationService =
      AttendanceReconciliationService();

  List<String> _approvalManagerIds(UserModel employee, String fallbackId) {
    return ManagerApprovalChain.orderedIds(
      employee.managerIds,
      fallbackId: fallbackId,
      teamLeaderId: employee.teamLeaderId,
    );
  }

  List<String> _approvalManagerNames(UserModel employee, String? fallbackName) {
    final ids = _approvalManagerIds(employee, employee.managerId ?? '');
    return ManagerApprovalChain.orderedNames(
      orderedIds: ids,
      managerIds: employee.managerIds,
      managerNames: employee.managerNames,
      teamLeaderId: employee.teamLeaderId,
      teamLeaderName: employee.teamLeaderName,
      fallbackManagerId: employee.managerId,
      fallbackManagerName: fallbackName,
    );
  }

  Map<String, dynamic> _nextManagerApprovalUpdate({
    required Map<String, dynamic> data,
    required String reviewerId,
    required String reviewerRole,
    required String finalStatus,
  }) {
    final managerIds =
        (data['managerIds'] as List<dynamic>?)
            ?.whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList() ??
        <String>[];
    final managerNames =
        (data['managerNames'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final currentManagerId = data['managerId'] as String? ?? '';
    final savedIndex = data['managerApprovalIndex'] as int?;
    final currentIndex = ManagerApprovalChain.currentIndex(
      managerIds: managerIds,
      currentManagerId: currentManagerId,
      savedIndex: savedIndex,
    );
    final nextIndex = currentIndex + 1;
    final trail = {
      'reviewerId': reviewerId,
      'reviewerRole': reviewerRole,
      'reviewedAt': Timestamp.now(),
      'stage': currentIndex < 0 ? 0 : currentIndex,
    };

    if (nextIndex >= 0 && nextIndex < managerIds.length) {
      return {
        'status': 'pending_manager',
        'managerId': managerIds[nextIndex],
        'managerName': nextIndex < managerNames.length
            ? managerNames[nextIndex]
            : null,
        'managerApprovalIndex': nextIndex,
        'managerApprovalTrail': FieldValue.arrayUnion([trail]),
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'managerReviewedBy': reviewerId,
        'managerReviewedAt': FieldValue.serverTimestamp(),
      };
    }

    return {
      'status': finalStatus,
      'managerApprovalIndex': managerIds.isEmpty ? 0 : managerIds.length - 1,
      'managerApprovalTrail': FieldValue.arrayUnion([trail]),
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'managerReviewedBy': reviewerId,
      'managerReviewedAt': FieldValue.serverTimestamp(),
    };
  }

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
    final requestDay = DateTime.parse(req.requestDate);
    final monthKey = PayrollCycle.keyFor(requestDay);
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

    // Submission after shift start remains visible for audit, but it no longer
    // rejects the request. Final approval reconciles any attendance deduction.
    var isLateSubmission = false;
    if (req.permissionType == 'late_arrival') {
      final workStartStr =
          employee.workSchedule.startTime ?? policyConfig.defaultStartTime;
      final startParts = workStartStr.split(':');
      final workStart = DateTime(
        requestDay.year,
        requestDay.month,
        requestDay.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
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

    final requiresHrOnlyApproval = employee.role == EmployeeRole.superAdmin;
    final managerIds = requiresHrOnlyApproval
        ? <String>[]
        : _approvalManagerIds(employee, req.managerId);
    final managerNames = requiresHrOnlyApproval
        ? <String>[]
        : _approvalManagerNames(employee, employee.managerName);
    if (managerIds.isEmpty && !requiresHrOnlyApproval) {
      throw Exception(
        'لا يمكن إرسال الطلب قبل تعيين مدير مباشر للموظف من إدارة الحسابات.',
      );
    }
    final firstManagerId = managerIds.isEmpty ? '' : managerIds.first;
    final permRef = _db.collection('permissions').doc();
    final finalStatus = requiresHrOnlyApproval
        ? 'pending_hr'
        : 'pending_manager';

    final finalModel = PermissionModel(
      permissionId: permRef.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: firstManagerId,
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

    await permRef.set({
      ...finalModel.toFirestore(),
      'requestDateTimestamp': Timestamp.fromDate(
        DateTime(
          req.requestDate.isEmpty
              ? now.year
              : int.parse(req.requestDate.substring(0, 4)),
          req.requestDate.isEmpty
              ? now.month
              : int.parse(req.requestDate.substring(5, 7)),
          req.requestDate.isEmpty
              ? now.day
              : int.parse(req.requestDate.substring(8, 10)),
        ),
      ),
      'expectedTimestamp': Timestamp.fromDate(
        DateTime(
          int.parse(req.requestDate.substring(0, 4)),
          int.parse(req.requestDate.substring(5, 7)),
          int.parse(req.requestDate.substring(8, 10)),
          int.parse(req.expectedTime.substring(0, 2)),
          int.parse(req.expectedTime.substring(3, 5)),
        ),
      ),
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
    });

    // ── Triggers notifications (No functions, direct Firestore write) ──
    if (requiresHrOnlyApproval) {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrAdmin,
        includeSuperAdmins: false,
        type: 'permission_pending_hr',
        title: 'طلب إذن لمالك النظام',
        body: '${req.employeeName} أرسل طلب إذن وينتظر قرار HR.',
        data: {'permissionId': permRef.id},
      );
    } else {
      await _createNotification(
        recipientId: firstManagerId,
        type: 'permission_pending_manager',
        title: 'طلب إذن بانتظار موافقتك',
        body:
            '${req.employeeName} يطلب إذن ${req.permissionType == 'late_arrival' ? 'تأخير حضور' : 'مغادرة مبكرة'}.'
            '${isExceedingQuota ? " (تجاوز الحد الشهري)" : ""}',
        data: {'permissionId': permRef.id},
      );
    }
  }

  Future<void> cancelPermission(String permissionId, String userId) async {
    final ref = _db.collection('permissions').doc(permissionId);
    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) throw Exception('طلب الإذن غير موجود.');
      final permission = PermissionModel.fromFirestore(doc);
      if (permission.userId != userId) {
        throw Exception('غير مسموح بإلغاء الطلب.');
      }
      if (permission.status == 'rejected' || permission.status == 'cancelled') {
        throw Exception('لا يمكن إلغاء هذا الطلب.');
      }
      final requestDay = DateTime.parse(permission.requestDate);
      final expectedParts = permission.expectedTime.split(':');
      final effectiveTime = DateTime(
        requestDay.year,
        requestDay.month,
        requestDay.day,
        int.parse(expectedParts[0]),
        int.parse(expectedParts[1]),
      );
      final today = DateTime.now();
      if (permission.status == 'approved' && !effectiveTime.isAfter(today)) {
        throw Exception('لا يمكن إلغاء إذن بدأ موعده بالفعل.');
      }
      transaction.update(ref, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
        if (permission.status == 'approved') 'balanceRestored': true,
      });
      if (permission.status == 'approved') {
        transaction.update(userRef, {
          'permissionBalance.usedThisMonth': FieldValue.increment(-1),
          'permissionBalance.usedHoursThisMonth': FieldValue.increment(
            -(permission.durationMinutes / 60.0),
          ),
          'lastPermissionBalanceRestorationId': permissionId,
        });
      }
    });
  }

  // Assigned managers approve sequentially, from direct to highest manager.
  Future<void> approvePermission(String permissionId, String reviewerId) async {
    final docRef = _db.collection('permissions').doc(permissionId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإذن غير موجود');
    final perm = PermissionModel.fromFirestore(doc);

    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerRole = (reviewerDoc.data()?['role'] as String?) ?? 'employee';
    final reviewerName =
        (reviewerDoc.data()?['displayName'] as String?)?.trim() ?? '';
    if (perm.status == 'pending_hr' && perm.userId == reviewerId) {
      throw Exception('لا يمكن اعتماد طلبك الشخصي. يجب أن يراجعه HR آخر.');
    }
    final requesterDoc = await _db.collection('users').doc(perm.userId).get();
    final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
    if (perm.status == 'pending_hr' &&
        requesterRole == EmployeeRole.superAdmin &&
        reviewerRole != EmployeeRole.hrAdmin &&
        reviewerRole != EmployeeRole.hrManager) {
      throw Exception('طلبات مالك النظام يراجعها HR أو مدير HR فقط.');
    }

    if (perm.status == 'pending_hr') {
      final data = doc.data() ?? <String, dynamic>{};
      final managerIds =
          (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          (perm.managerId.isEmpty ? <String>[] : <String>[perm.managerId]);
      final managerNames =
          (data['managerNames'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          <String>[];
      final approvalTrail =
          (data['managerApprovalTrail'] as List<dynamic>?) ?? <dynamic>[];
      final managersCompleted =
          managerIds.isEmpty || approvalTrail.length >= managerIds.length;
      final firstManagerId = managerIds.isNotEmpty ? managerIds.first : '';
      final update = {
        'status': managersCompleted ? 'approved' : 'pending_manager',
        if (!managersCompleted && firstManagerId.isNotEmpty)
          'managerId': firstManagerId,
        if (!managersCompleted && managerNames.isNotEmpty)
          'managerName': managerNames.first,
        if (!managersCompleted) 'managerApprovalIndex': 0,
        'hrReviewedBy': reviewerId,
        'hrReviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': FieldValue.serverTimestamp(),
      };

      if (managersCompleted) {
        final batch = _db.batch();
        batch.update(docRef, update);
        batch.update(_db.collection('users').doc(perm.userId), {
          'permissionBalance.usedThisMonth': FieldValue.increment(1),
          'permissionBalance.usedHoursThisMonth': FieldValue.increment(
            perm.durationMinutes / 60.0,
          ),
        });
        await batch.commit();
      } else {
        await docRef.update(update);
      }

      await AuditLogService.instance.record(
        actorId: reviewerId,
        action: 'permission_hr_approved',
        targetCollection: 'permissions',
        targetId: permissionId,
        metadata: {'userId': perm.userId, 'managerId': perm.managerId},
      );

      if (!managersCompleted && firstManagerId.isNotEmpty) {
        try {
          await _createNotification(
            recipientId: firstManagerId,
            type: 'permission_pending_manager',
            title: 'طلب إذن بانتظار موافقتك',
            body:
                '${perm.employeeName} حصل على موافقة HR وينتظر قرارك النهائي.',
            data: {'permissionId': permissionId},
          );
        } catch (_) {}
      } else {
        await _reconciliationService.reconcileApprovedPermission(perm);
        try {
          await _createNotification(
            recipientId: perm.userId,
            type: 'permission_approved',
            title: 'تم قبول طلب الإذن',
            body:
                'تمت الموافقة النهائية على طلب إذنك ليوم ${perm.requestDate}. سبب الطلب: ${perm.reason}',
            data: {
              'permissionId': permissionId,
              'route': '/employee/requests',
              'decision': 'approved',
            },
          );
        } catch (_) {}
      }
      return;
    }

    if (perm.status != 'pending_manager') {
      throw Exception('طلب الإذن ليس في مرحلة موافقة المدير.');
    }

    if (!EmployeeRole.canActAsApprovalManager(reviewerRole)) {
      throw Exception('هذا الطلب ينتظر موافقة المدير.');
    }
    if (perm.managerId != reviewerId) {
      throw Exception(
        'هذا الطلب ينتظر موافقة المدير المحدد في المرحلة الحالية.',
      );
    }

    final batch = _db.batch();
    final approvalPolicy = await _approvalPolicyService.getPolicy();
    final nextUpdate = _nextManagerApprovalUpdate(
      data: doc.data() ?? <String, dynamic>{},
      reviewerId: reviewerId,
      reviewerRole: reviewerRole,
      finalStatus: approvalPolicy.finalManagerApprovalStatus,
    );
    nextUpdate['reviewerName'] = reviewerName;

    // 1. Update status
    batch.update(docRef, nextUpdate);

    // 2. Increment employee quota counters
    if (nextUpdate['status'] == 'approved') {
      final userRef = _db.collection('users').doc(perm.userId);
      batch.update(userRef, {
        'permissionBalance.usedThisMonth': FieldValue.increment(1),
        'permissionBalance.usedHoursThisMonth': FieldValue.increment(
          perm.durationMinutes / 60.0,
        ),
      });
    }

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

    if (nextUpdate['status'] == 'pending_manager') {
      final nextManagerId = nextUpdate['managerId'] as String?;
      if (nextManagerId != null && nextManagerId.isNotEmpty) {
        try {
          await _createNotification(
            recipientId: nextManagerId,
            type: 'permission_pending_manager',
            title: 'طلب إذن بانتظار موافقتك',
            body: '${perm.employeeName} حصل على موافقة مدير سابق وينتظر قرارك.',
            data: {'permissionId': permissionId},
          );
        } catch (_) {}
      }
      return;
    }

    if (nextUpdate['status'] == 'pending_hr') {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrAdmin,
        type: 'permission_pending_hr',
        title: 'طلب إذن بانتظار مراجعة HR',
        body:
            'اكتملت موافقات المديرين على طلب ${perm.employeeName} وينتظر القرار النهائي من HR.',
        data: {'permissionId': permissionId},
      );
      return;
    }

    // 3. Notify employee
    await _reconciliationService.reconcileApprovedPermission(perm);
    try {
      await _createNotification(
        recipientId: perm.userId,
        type: 'permission_approved',
        title: 'تم قبول طلب الإذن ✅',
        body:
            'اكتملت موافقات المديرين على طلب إذنك ليوم ${perm.requestDate}. سبب الطلب: ${perm.reason}',
        data: {
          'permissionId': permissionId,
          'route': '/employee/requests',
          'decision': 'approved',
        },
      );
    } catch (_) {}
  }

  // The manager assigned to the current stage can reject the permission.
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
    final reviewerName =
        (reviewerDoc.data()?['displayName'] as String?)?.trim() ?? '';
    final isHrStage = perm.status == 'pending_hr'; // Legacy requests only.
    if (isHrStage && perm.userId == reviewerId) {
      throw Exception('لا يمكن رفض طلبك الشخصي. يجب أن يراجعه HR آخر.');
    }
    final requesterDoc = await _db.collection('users').doc(perm.userId).get();
    final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
    if (isHrStage &&
        requesterRole == EmployeeRole.superAdmin &&
        reviewerRole != EmployeeRole.hrAdmin &&
        reviewerRole != EmployeeRole.hrManager) {
      throw Exception('طلبات مالك النظام يراجعها HR أو مدير HR فقط.');
    }
    if (!isHrStage && perm.managerId != reviewerId) {
      throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
    }

    await docRef.update({
      'status': 'rejected',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerComment': comment,
      'reviewerName': reviewerName,
      if (isHrStage) 'hrReviewedBy': reviewerId,
      if (isHrStage) 'hrReviewedAt': FieldValue.serverTimestamp(),
      if (isHrStage) 'hrReviewerComment': comment,
      if (!isHrStage && EmployeeRole.canActAsApprovalManager(reviewerRole))
        'managerReviewedBy': reviewerId,
      if (!isHrStage && EmployeeRole.canActAsApprovalManager(reviewerRole))
        'managerReviewedAt': FieldValue.serverTimestamp(),
      if (!isHrStage && EmployeeRole.canActAsApprovalManager(reviewerRole))
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
        data: {
          'permissionId': permissionId,
          'route': '/employee/requests',
          'decision': 'rejected',
          'decisionReason': comment,
        },
      );
    } catch (_) {}
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
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
