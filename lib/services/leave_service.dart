import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import '../models/user_model.dart';
import '../models/leave_model.dart';
import '../models/leave_type_policy.dart';
import '../models/leave_entitlement_policy.dart';
import '../models/manager_approval_chain.dart';
import '../models/notification_route_policy.dart';
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

  static void validateBalance(LeaveModel request, LeaveBalance balance) {
    if (request.leaveType == LeaveTypePolicy.normal &&
        request.numberOfDays > balance.daysOff) {
      throw Exception('رصيد الإجازات الكلي غير كافٍ.');
    }
    if (request.leaveType == LeaveTypePolicy.casual) {
      if (request.numberOfDays > balance.casual) {
        throw Exception('رصيد الإجازات العارضة غير كافٍ.');
      }
      if (request.numberOfDays > balance.daysOff) {
        throw Exception('رصيد الإجازات الكلي غير كافٍ.');
      }
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

  List<String> _approvalManagerIds(UserModel employee) {
    return ManagerApprovalChain.orderedIds(
      employee.managerIds,
      fallbackId: employee.managerId,
      teamLeaderId: employee.teamLeaderId,
    );
  }

  List<String> _approvalManagerNames(UserModel employee, String? fallbackName) {
    final ids = _approvalManagerIds(employee);
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
    required String reviewerName,
    required String finalStatus,
    required bool requiresCeoApproval,
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
      'reviewerName': reviewerName,
      'action': 'approved',
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
        'reviewerName': reviewerName,
        'approvalHistory': FieldValue.arrayUnion([trail]),
      };
    }

    return {
      'status': requiresCeoApproval && finalStatus == 'approved'
          ? 'pending_hr'
          : finalStatus,
      'managerApprovalIndex': managerIds.isEmpty ? 0 : managerIds.length - 1,
      'managerApprovalTrail': FieldValue.arrayUnion([trail]),
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerName': reviewerName,
      'approvalHistory': FieldValue.arrayUnion([trail]),
    };
  }

  Map<String, dynamic> _approvalEvent({
    required String stage,
    required String status,
    required String actorId,
    required String actorName,
    String? comment,
  }) {
    return {
      'stage': stage,
      'status': status,
      'actorId': actorId,
      'actorName': actorName,
      'timestamp': Timestamp.now(),
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    };
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _companyCeo() async {
    final result = await _db
        .collection('users')
        .where('employeeId', isEqualTo: 'CEO-100')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (result.docs.isEmpty) {
      throw Exception(
        'لا يوجد حساب نشط بكود CEO-100. أضف الحساب قبل اعتماد إجازة تتجاوز 4 أيام.',
      );
    }
    return result.docs.first;
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
    if (req.leaveType == LeaveTypePolicy.normal &&
        employee.hiringDate == null) {
      throw Exception(
        'يجب أن تسجل إدارة الموارد البشرية تاريخ التعيين قبل طلب إجازة سنوية.',
      );
    }
    final probationConversion =
        req.leaveType == LeaveTypePolicy.normal &&
        LeaveEntitlementPolicy.isOnProbation(
          employee.hiringDate,
          onDate: req.startDate,
        );
    final effectiveType = probationConversion
        ? LeaveTypePolicy.unpaid
        : req.leaveType;
    final effectiveRequest = LeaveModel(
      leaveId: req.leaveId,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      leaveType: effectiveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      workHandoverTo: req.workHandoverTo,
      status: req.status,
      submittedAt: req.submittedAt,
    );
    validateBalance(effectiveRequest, employee.leaveBalance);

    // 1. Validate overlaps (basic check against other active leaves)
    final overlaps = await _db
        .collection('leaves')
        .where('userId', isEqualTo: req.userId)
        .where(
          'status',
          whereIn: ['approved', 'pending_hr', 'pending_manager', 'pending_ceo'],
        )
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
    final managerIds = _approvalManagerIds(employee);
    final managerNames = _approvalManagerNames(employee, employee.managerName);
    final usesHrFallback = ManagerApprovalChain.usesHrFallback(
      isSuperAdmin: employee.role == EmployeeRole.superAdmin,
      managerIds: managerIds,
    );
    if (managerIds.isEmpty && !usesHrFallback) {
      throw Exception(
        'لا يمكن إرسال الطلب قبل تعيين مدير مباشر للموظف من إدارة الحسابات.',
      );
    }
    final isAutoApprovedCasual =
        effectiveType == LeaveTypePolicy.casual && req.numberOfDays <= 4;
    final approvalManagerIds = isAutoApprovedCasual ? <String>[] : managerIds;
    final approvalManagerNames = isAutoApprovedCasual
        ? <String>[]
        : managerNames;
    final firstManagerId = approvalManagerIds.isEmpty
        ? ''
        : approvalManagerIds.first;
    final finalModel = LeaveModel(
      leaveId: reqRef.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: firstManagerId,
      leaveType: effectiveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      workHandoverTo: req.workHandoverTo,
      status: isAutoApprovedCasual
          ? 'approved'
          : (usesHrFallback ? 'pending_hr' : 'pending_manager'),
      submittedAt: DateTime.now(),
    );

    final leaveData = {
      ...finalModel.toFirestore(),
      'deductsLeaveBalance': LeaveTypePolicy.balanceKeys(
        effectiveType,
      ).isNotEmpty,
      if (LeaveTypePolicy.balanceKey(effectiveType) != null)
        'leaveBalanceKey': LeaveTypePolicy.balanceKey(effectiveType),
      if (LeaveTypePolicy.balanceKeys(effectiveType).isNotEmpty)
        'leaveBalanceKeys': LeaveTypePolicy.balanceKeys(effectiveType),
      'requiresFullDaySalaryDeduction':
          LeaveTypePolicy.requiresFullDaySalaryDeduction(effectiveType),
      'managerIds': approvalManagerIds,
      'managerNames': approvalManagerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': approvalManagerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'approvalHistory': [
        _approvalEvent(
          stage: 'submitted',
          status: 'completed',
          actorId: employee.uid,
          actorName: employee.displayName,
        ),
      ],
      'requiresCeoApproval': req.numberOfDays > 4,
      if (probationConversion) ...{
        'originalLeaveType': req.leaveType,
        'probationConverted': true,
      },
      if (isAutoApprovedCasual) 'autoApproved': true,
    };

    if (isAutoApprovedCasual) {
      final userRef = _db.collection('users').doc(employee.uid);
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception('حساب الموظف غير موجود.');
        final latestBalance = UserModel.fromFirestore(
          userSnapshot,
        ).leaveBalance;
        validateBalance(effectiveRequest, latestBalance);
        transaction.set(reqRef, leaveData);
        transaction.update(userRef, {
          'leaveBalance.casual': FieldValue.increment(-req.numberOfDays),
          'leaveBalance.daysOff': FieldValue.increment(-req.numberOfDays),
          'lastAutoApprovedCasualLeaveId': reqRef.id,
        });
      });
      await _createNotification(
        recipientId: employee.uid,
        type: 'leave_auto_approved',
        title: 'تم اعتماد الإجازة العارضة',
        body:
            'تم اعتماد الإجازة العارضة تلقائياً وخصم ${req.numberOfDays} يوم من رصيد العارضة والرصيد الكلي.',
        data: {'leaveId': reqRef.id},
      );
      await _reconciliationService.reconcileApprovedLeave(finalModel);
      return;
    }

    await reqRef.set(leaveData);

    if (usesHrFallback) {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrManager,
        includeSuperAdmins: false,
        type: 'leave_request_submitted',
        title: 'طلب إجازة بدون مدير معيّن',
        body:
            '${req.employeeName} أرسل ${LeaveTypePolicy.arabicLabel(req.leaveType)} وينتظر قرار مدير HR.',
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
      final balanceKeys = LeaveTypePolicy.balanceKeys(leave.leaveType);
      transaction.update(ref, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
        if (leave.status == 'approved' && balanceKeys.isNotEmpty)
          'balanceRestored': true,
      });
      if (leave.status == 'approved' && balanceKeys.isNotEmpty) {
        transaction.update(userRef, {
          for (final key in balanceKeys)
            'leaveBalance.$key': FieldValue.increment(leave.numberOfDays),
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
    final requiresCeoApproval =
        (data['requiresCeoApproval'] as bool?) ?? leave.numberOfDays > 4;

    if (leave.status == 'pending_ceo') {
      final reviewerCode =
          (reviewerDoc.data()?['employeeId'] as String?)?.trim() ?? '';
      if (reviewerCode != 'CEO-100') {
        throw Exception('الاعتماد النهائي لهذا الطلب متاح لحساب CEO-100 فقط.');
      }
      final event = _approvalEvent(
        stage: 'ceo',
        status: 'approved',
        actorId: reviewerId,
        actorName: reviewerName,
      );
      await docRef.update({
        'status': 'approved',
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': FieldValue.serverTimestamp(),
        'finalApproverId': reviewerId,
        'finalApproverName': reviewerName,
        'finalApprovalAt': FieldValue.serverTimestamp(),
        'approvalHistory': FieldValue.arrayUnion([event]),
      });
      await _finalizeApprovedLeave(leave, reviewerId);
      return;
    }

    if (leave.status == 'pending_hr') {
      final requesterDoc = await _db
          .collection('users')
          .doc(leave.userId)
          .get();
      final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
      if (leave.userId == reviewerId) {
        throw Exception('لا يمكن اعتماد طلبك الشخصي. يجب أن يراجعه HR آخر.');
      }
      if (!EmployeeRole.isHrStaff(role)) {
        throw Exception('هذه المرحلة يراجعها HR أو مدير HR فقط.');
      }
      final managerIds =
          (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      if (managerIds.isEmpty && role != EmployeeRole.hrManager) {
        throw Exception('الطلبات بدون مدير معيّن يراجعها مدير HR فقط.');
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

    if (EmployeeRole.isHrStaff(role)) {
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
        final nextStatus = managersCompleted
            ? (requiresCeoApproval ? 'pending_ceo' : 'approved')
            : 'pending_manager';
        update = {
          'status': nextStatus,
          if (!managersCompleted && firstManagerId.isNotEmpty)
            'managerId': firstManagerId,
          if (!managersCompleted && managerNames.isNotEmpty)
            'managerName': managerNames.first,
          if (!managersCompleted) 'managerApprovalIndex': 0,
          'reviewedBy': reviewerId,
          'reviewerName': reviewerName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            _approvalEvent(
              stage: 'hr',
              status: 'approved',
              actorId: reviewerId,
              actorName: reviewerName,
            ),
          ]),
        };
        if (nextStatus == 'pending_ceo') {
          final ceo = await _companyCeo();
          update['ceoId'] = ceo.id;
          update['ceoName'] = ceo.data()['displayName'] as String? ?? 'CEO';
        }
        isFinalApproval = nextStatus == 'approved';
      } else {
        if (leave.managerId != reviewerId) {
          throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
        }
        final approvalPolicy = await _approvalPolicyService.getPolicy();
        update = _nextManagerApprovalUpdate(
          data: data,
          reviewerId: reviewerId,
          reviewerRole: role,
          reviewerName: reviewerName,
          finalStatus: approvalPolicy.finalManagerApprovalStatus,
          requiresCeoApproval: requiresCeoApproval,
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
        reviewerName: reviewerName,
        finalStatus: approvalPolicy.finalManagerApprovalStatus,
        requiresCeoApproval: requiresCeoApproval,
      );
      isFinalApproval = update['status'] == 'approved';
    }

    update['reviewerName'] = reviewerName;

    batch.update(docRef, update);

    if (isFinalApproval) {
      // Deduct leave balance
      final balanceKeys = LeaveTypePolicy.balanceKeys(leave.leaveType);

      final userRef = _db.collection('users').doc(leave.userId);
      if (balanceKeys.isNotEmpty) {
        final userSnapshot = await userRef.get();
        if (!userSnapshot.exists) throw Exception('حساب الموظف غير موجود.');
        final balance = UserModel.fromFirestore(userSnapshot).leaveBalance;
        validateBalance(leave, balance);
        batch.update(userRef, {
          for (final key in balanceKeys)
            'leaveBalance.$key': FieldValue.increment(-leave.numberOfDays),
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
        includeSuperAdmins: false,
        type: 'leave_request_submitted',
        title: 'طلب إجازة بانتظار مراجعة HR',
        body:
            'اكتملت موافقات المديرين على طلب ${leave.employeeName} وينتظر القرار النهائي من HR.',
        data: {'leaveId': leaveId},
      );
      return;
    }

    if (update['status'] == 'pending_ceo') {
      final ceoId = update['ceoId'] as String?;
      if (ceoId == null || ceoId.isEmpty) {
        throw Exception('تعذر تحديد حساب CEO-100.');
      }
      await _createNotification(
        recipientId: ceoId,
        type: 'leave_request_submitted',
        title: 'إجازة طويلة بانتظار اعتماد CEO',
        body:
            'طلب ${leave.employeeName} لمدة ${leave.numberOfDays} أيام أكمل موافقة المدير وHR.',
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

  Future<void> _finalizeApprovedLeave(
    LeaveModel leave,
    String reviewerId,
  ) async {
    final balanceKeys = LeaveTypePolicy.balanceKeys(leave.leaveType);
    if (balanceKeys.isNotEmpty) {
      final userRef = _db.collection('users').doc(leave.userId);
      final userSnapshot = await userRef.get();
      if (!userSnapshot.exists) throw Exception('حساب الموظف غير موجود.');
      final balance = UserModel.fromFirestore(userSnapshot).leaveBalance;
      validateBalance(leave, balance);
      await userRef.update({
        for (final key in balanceKeys)
          'leaveBalance.$key': FieldValue.increment(-leave.numberOfDays),
      });
    }
    await _reconciliationService.reconcileApprovedLeave(leave);
    await _createNotification(
      recipientId: leave.userId,
      type: 'leave_approved',
      title: 'تم قبول طلب الإجازة',
      body: 'تم اعتماد إجازتك لمدة ${leave.numberOfDays} يوم.',
      data: {'leaveId': leave.leaveId, 'route': '/employee/requests'},
    );
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
    if (leave.status == 'pending_ceo') {
      final reviewerCode =
          (reviewerDoc.data()?['employeeId'] as String?)?.trim() ?? '';
      if (reviewerCode != 'CEO-100') {
        throw Exception('رفض هذا الطلب متاح لحساب CEO-100 فقط.');
      }
    }
    if (leave.status == 'pending_hr') {
      final requesterDoc = await _db
          .collection('users')
          .doc(leave.userId)
          .get();
      final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
      if (leave.userId == reviewerId) {
        throw Exception('لا يمكن رفض طلبك الشخصي. يجب أن يراجعه HR آخر.');
      }
      if (!EmployeeRole.isHrStaff(reviewerRole)) {
        throw Exception('هذه المرحلة يراجعها HR أو مدير HR فقط.');
      }
      final managerIds =
          (doc.data()?['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      if (managerIds.isEmpty && reviewerRole != EmployeeRole.hrManager) {
        throw Exception('الطلبات بدون مدير معيّن يراجعها مدير HR فقط.');
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
      'finalApproverId': reviewerId,
      'finalApproverName': reviewerName,
      'finalApprovalAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([
        _approvalEvent(
          stage: leave.status == 'pending_ceo'
              ? 'ceo'
              : leave.status == 'pending_hr'
              ? 'hr'
              : 'manager',
          status: 'rejected',
          actorId: reviewerId,
          actorName: reviewerName,
          comment: comment,
        ),
      ]),
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
      'data': NotificationRoutePolicy.dataWithRoute(type, data),
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
