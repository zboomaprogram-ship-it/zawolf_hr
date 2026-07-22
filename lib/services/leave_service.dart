import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import '../models/user_model.dart';
import '../models/leave_model.dart';
import '../models/leave_type_policy.dart';
import '../models/manager_approval_chain.dart';
import 'audit_log_service.dart';
import 'request_approval_policy_service.dart';
import 'role_notification_service.dart';
import 'attendance_reconciliation_service.dart';

class LeaveService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final RequestApprovalPolicyService _approvalPolicyService =
      RequestApprovalPolicyService();
  final AttendanceReconciliationService _reconciliationService =
      AttendanceReconciliationService();

  static void validateRequest(LeaveModel request, {DateTime? now}) {
    if (!LeaveTypePolicy.supportedTypes.contains(request.leaveType)) {
      throw Exception('اختر نوع إجازة صحيحاً.');
    }
    if ((request.reason ?? '').trim().isEmpty) {
      throw Exception('يجب كتابة سبب الإجازة.');
    }
    if (request.workHandoverTo.trim().isEmpty) {
      throw Exception('يجب تحديد من سيقوم بالعمل أثناء الإجازة.');
    }
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final start = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final end = DateTime(
      request.endDate.year,
      request.endDate.month,
      request.endDate.day,
    );
    if (end.isBefore(start)) {
      throw Exception('تاريخ نهاية الإجازة يسبق تاريخ البداية.');
    }
    if (start.isBefore(today)) {
      throw Exception('لا يمكن تقديم طلب إجازة عن يوم سابق.');
    }
    if (LeaveTypePolicy.requiresTwoDayNotice(request.leaveType) &&
        start.isBefore(today.add(const Duration(days: 2)))) {
      throw Exception(
        'الإجازة العادية يجب تقديمها قبل موعدها بيومين على الأقل.',
      );
    }
  }

  String _attachmentContentType(String pathOrExtension) {
    final extension = pathOrExtension.split('.').last.trim().toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/pdf';
    }
  }

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
      };
    }

    return {
      'status': finalStatus,
      'managerApprovalIndex': managerIds.isEmpty ? 0 : managerIds.length - 1,
      'managerApprovalTrail': FieldValue.arrayUnion([trail]),
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
    };
  }

  // Upload certificate attachment to Firebase Storage (supports mobile & web via bytes)
  Future<String> uploadAttachment({
    required String leaveId,
    required String userId,
    required Uint8List fileBytes,
    required String fileExtension,
  }) async {
    final ref = _storage.ref().child(
      'leaves/$userId/${leaveId}_cert.$fileExtension',
    );
    final uploadTask = await ref.putData(
      fileBytes,
      SettableMetadata(contentType: _attachmentContentType(fileExtension)),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // Upload certificate from local file path (mobile fallback)
  Future<String> uploadAttachmentFromFile({
    required String leaveId,
    required String userId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final fileExtension = filePath.split('.').last;
    final ref = _storage.ref().child(
      'leaves/$userId/${leaveId}_cert.$fileExtension',
    );
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: _attachmentContentType(fileExtension)),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // Submit leave request
  Future<void> submitLeaveRequest(LeaveModel req, UserModel employee) async {
    validateRequest(req);

    // 1. Validate overlaps (basic check against other active leaves)
    final overlaps = await _db
        .collection('leaves')
        .where('userId', isEqualTo: req.userId)
        .where('status', whereIn: ['approved', 'pending_hr', 'pending_manager'])
        .get();

    for (final doc in overlaps.docs) {
      final existing = LeaveModel.fromFirestore(doc);
      if (req.startDate.isBefore(
            existing.endDate.add(const Duration(days: 1)),
          ) &&
          req.endDate.isAfter(
            existing.startDate.subtract(const Duration(days: 1)),
          )) {
        throw Exception('يوجد طلب إجازة متداخل آخر بالفعل في هذه التواريخ.');
      }
    }

    final reqRef = _db.collection('leaves').doc();
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
    final finalModel = LeaveModel(
      leaveId: reqRef.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: firstManagerId,
      leaveType: req.leaveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      workHandoverTo: req.workHandoverTo,
      status: requiresHrOnlyApproval ? 'pending_hr' : 'pending_manager',
      submittedAt: DateTime.now(),
    );

    await reqRef.set({
      ...finalModel.toFirestore(),
      'deductsLeaveBalance': LeaveTypePolicy.balanceKey(req.leaveType) != null,
      if (LeaveTypePolicy.balanceKey(req.leaveType) != null)
        'leaveBalanceKey': LeaveTypePolicy.balanceKey(req.leaveType),
      'requiresFullDaySalaryDeduction':
          LeaveTypePolicy.requiresFullDaySalaryDeduction(req.leaveType),
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
    });

    if (requiresHrOnlyApproval) {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrAdmin,
        includeSuperAdmins: false,
        type: 'leave_request_submitted',
        title: 'طلب إجازة لمالك النظام',
        body:
            '${req.employeeName} أرسل ${LeaveTypePolicy.arabicLabel(req.leaveType)} وينتظر قرار HR.',
        data: {'leaveId': reqRef.id},
      );
    } else {
      await _createNotification(
        recipientId: firstManagerId,
        type: 'leave_request_submitted',
        title: 'طلب إجازة بانتظار موافقتك',
        body:
            'يطلب ${req.employeeName} ${LeaveTypePolicy.arabicLabel(req.leaveType)} لمدّة ${req.numberOfDays} يوم. تسليم العمل إلى: ${req.workHandoverTo}.',
        data: {'leaveId': reqRef.id},
      );
    }
  }

  Future<void> cancelLeave(String leaveId, String userId) async {
    final ref = _db.collection('leaves').doc(leaveId);
    final userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) throw Exception('طلب الإجازة غير موجود.');
      final leave = LeaveModel.fromFirestore(doc);
      if (leave.userId != userId) throw Exception('غير مسموح بإلغاء الطلب.');
      if (leave.status == 'rejected' || leave.status == 'cancelled') {
        throw Exception('لا يمكن إلغاء هذا الطلب.');
      }
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      if (leave.status == 'approved' && !leave.startDate.isAfter(todayOnly)) {
        throw Exception('لا يمكن إلغاء إجازة بدأت بالفعل.');
      }
      final balanceKey = LeaveTypePolicy.balanceKey(leave.leaveType);
      transaction.update(ref, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
        if (leave.status == 'approved' && balanceKey != null)
          'balanceRestored': true,
      });
      if (leave.status == 'approved' && balanceKey != null) {
        transaction.update(userRef, {
          'leaveBalance.$balanceKey': FieldValue.increment(leave.numberOfDays),
          'lastLeaveBalanceRestorationId': leaveId,
        });
      }
    });
  }

  // Approve Leave
  Future<void> approveLeave(
    String leaveId,
    String reviewerId,
    String role,
  ) async {
    final docRef = _db.collection('leaves').doc(leaveId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإجازة غير موجود');
    final leave = LeaveModel.fromFirestore(doc);
    final data = doc.data() ?? <String, dynamic>{};
    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerName =
        (reviewerDoc.data()?['displayName'] as String?)?.trim() ?? '';

    if (leave.status == 'pending_hr') {
      final requesterDoc = await _db
          .collection('users')
          .doc(leave.userId)
          .get();
      final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
      if (leave.userId == reviewerId) {
        throw Exception('لا يمكن اعتماد طلبك الشخصي. يجب أن يراجعه HR آخر.');
      }
      if (requesterRole == EmployeeRole.superAdmin &&
          role != EmployeeRole.hrAdmin &&
          role != EmployeeRole.hrManager) {
        throw Exception('طلبات مالك النظام يراجعها HR أو مدير HR فقط.');
      }
    }

    final batch = _db.batch();

    bool isFinalApproval = false;
    Map<String, dynamic> update;

    if (role == EmployeeRole.hrAdmin ||
        role == EmployeeRole.hrManager ||
        role == EmployeeRole.superAdmin) {
      if (leave.status == 'pending_hr') {
        final managerIds =
            (data['managerIds'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            (leave.managerId.isEmpty ? <String>[] : <String>[leave.managerId]);
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
        update = {
          'status': managersCompleted ? 'approved' : 'pending_manager',
          if (!managersCompleted && firstManagerId.isNotEmpty)
            'managerId': firstManagerId,
          if (!managersCompleted && managerNames.isNotEmpty)
            'managerName': managerNames.first,
          if (!managersCompleted) 'managerApprovalIndex': 0,
          'reviewedBy': reviewerId,
          'reviewerName': reviewerName,
          'reviewedAt': FieldValue.serverTimestamp(),
        };
        isFinalApproval = managersCompleted;
      } else {
        if (leave.managerId != reviewerId) {
          throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
        }
        final approvalPolicy = await _approvalPolicyService.getPolicy();
        update = _nextManagerApprovalUpdate(
          data: data,
          reviewerId: reviewerId,
          reviewerRole: role,
          finalStatus: approvalPolicy.finalManagerApprovalStatus,
        );
        isFinalApproval = update['status'] == 'approved';
      }
    } else {
      // Manager
      if (leave.managerId != reviewerId) {
        throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
      }
      final approvalPolicy = await _approvalPolicyService.getPolicy();
      update = _nextManagerApprovalUpdate(
        data: data,
        reviewerId: reviewerId,
        reviewerRole: role,
        finalStatus: approvalPolicy.finalManagerApprovalStatus,
      );
      isFinalApproval = update['status'] == 'approved';
    }

    update['reviewerName'] = reviewerName;

    batch.update(docRef, update);

    if (isFinalApproval) {
      // Deduct leave balance
      final balanceKey = LeaveTypePolicy.balanceKey(leave.leaveType);

      final userRef = _db.collection('users').doc(leave.userId);
      if (balanceKey != null) {
        batch.update(userRef, {
          'leaveBalance.$balanceKey': FieldValue.increment(-leave.numberOfDays),
        });
      }
    }

    await batch.commit();

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'leave_approved',
      targetCollection: 'leaves',
      targetId: leaveId,
      metadata: {
        'userId': leave.userId,
        'numberOfDays': leave.numberOfDays,
        'leaveType': leave.leaveType,
      },
    );

    if (update['status'] == 'pending_manager') {
      final nextManagerId = update['managerId'] as String?;
      if (nextManagerId != null && nextManagerId.isNotEmpty) {
        try {
          await _createNotification(
            recipientId: nextManagerId,
            type: 'leave_request_submitted',
            title: 'طلب إجازة بانتظار موافقتك',
            body: '${leave.employeeName} حصل على موافقة سابقة وينتظر قرارك.',
            data: {'leaveId': leaveId},
          );
        } catch (_) {}
      }
      return;
    }

    if (update['status'] == 'pending_hr') {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrAdmin,
        type: 'leave_request_submitted',
        title: 'طلب إجازة بانتظار مراجعة HR',
        body:
            'اكتملت موافقات المديرين على طلب ${leave.employeeName} وينتظر القرار النهائي من HR.',
        data: {'leaveId': leaveId},
      );
      return;
    }

    // 3. Notify employee
    await _reconciliationService.reconcileApprovedLeave(leave);
    try {
      await _createNotification(
        recipientId: leave.userId,
        type: 'leave_approved',
        title: 'تم قبول طلب الإجازة ✅',
        body:
            'تمت الموافقة على طلب إجازتك لمدّة ${leave.numberOfDays} يوم. السبب المسجل: ${leave.reason}',
        data: {
          'leaveId': leaveId,
          'route': '/employee/requests',
          'decision': 'approved',
          'resyncAttendanceAlarm': true,
        },
      );
    } catch (_) {}
  }

  // Reject Leave
  Future<void> rejectLeave(
    String leaveId,
    String reviewerId,
    String comment,
  ) async {
    final docRef = _db.collection('leaves').doc(leaveId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإجازة غير موجود');
    final leave = LeaveModel.fromFirestore(doc);
    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerRole = reviewerDoc.data()?['role'] as String? ?? '';
    final reviewerName =
        (reviewerDoc.data()?['displayName'] as String?)?.trim() ?? '';
    if (leave.status == 'pending_hr') {
      final requesterDoc = await _db
          .collection('users')
          .doc(leave.userId)
          .get();
      final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
      if (leave.userId == reviewerId) {
        throw Exception('لا يمكن رفض طلبك الشخصي. يجب أن يراجعه HR آخر.');
      }
      if (requesterRole == EmployeeRole.superAdmin &&
          reviewerRole != EmployeeRole.hrAdmin &&
          reviewerRole != EmployeeRole.hrManager) {
        throw Exception('طلبات مالك النظام يراجعها HR أو مدير HR فقط.');
      }
    }
    if (leave.status == 'pending_manager' && leave.managerId != reviewerId) {
      throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
    }

    await docRef.update({
      'status': 'rejected',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerComment': comment,
      'reviewerName': reviewerName,
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'leave_rejected',
      targetCollection: 'leaves',
      targetId: leaveId,
      metadata: {'userId': leave.userId, 'leaveType': leave.leaveType},
    );

    // Notify employee
    try {
      await _createNotification(
        recipientId: leave.userId,
        type: 'leave_rejected',
        title: 'تم رفض طلب الإجازة ❌',
        body: 'تم رفض طلب إجازتك. السبب: $comment',
        data: {
          'leaveId': leaveId,
          'route': '/employee/requests',
          'decision': 'rejected',
          'decisionReason': comment,
          'resyncAttendanceAlarm': true,
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
