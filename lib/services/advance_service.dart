import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/advance_model.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';
import 'audit_log_service.dart';
import 'role_notification_service.dart';

class AdvanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Validates the rules before allocating an id or writing a request.  Keeping
  /// this deterministic makes the same policy available to every client.
  static void validateSubmissionEligibility({
    required UserModel employee,
    required double amount,
    required DateTime now,
  }) {
    if (employee.hiringDate == null ||
        now.difference(employee.hiringDate!).inDays < 90) {
      throw Exception('لا يمكن طلب سلفة قبل قضاء 3 أشهر على الأقل في الخدمة.');
    }
    if (now.day < 15) {
      throw Exception(
        'يُتاح تقديم طلب السلفة فقط بدءاً من يوم 15 في الشهر الميلادي.',
      );
    }
    final maximum = employee.baseMonthlySalary * .5;
    if (maximum <= 0 || amount > maximum) {
      throw Exception(
        'قيمة السلفة لا يمكن أن تتجاوز 50% من الراتب الشهري (الحد الأقصى المتاح لك: ${maximum.toStringAsFixed(0)} ${employee.salaryCurrency}).',
      );
    }
  }

  List<String> _approvalManagerIds(UserModel employee, String fallbackId) {
    final ids =
        employee.managerIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isNotEmpty) return ids;
    return fallbackId.trim().isEmpty ? <String>[] : <String>[fallbackId];
  }

  List<String> _approvalManagerNames(UserModel employee, String? fallbackName) {
    final names =
        employee.managerNames.where((name) => name.trim().isNotEmpty).toList();
    if (names.isNotEmpty) return names;
    return fallbackName == null || fallbackName.trim().isEmpty
        ? <String>[]
        : <String>[fallbackName];
  }

  Map<String, dynamic> _nextManagerApprovalUpdate({
    required Map<String, dynamic> data,
    required String reviewerId,
    required String reviewerRole,
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
    final currentIndex = savedIndex ?? managerIds.indexOf(currentManagerId);
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
        'managerName':
            nextIndex < managerNames.length ? managerNames[nextIndex] : null,
        'managerApprovalIndex': nextIndex,
        'managerApprovalTrail': FieldValue.arrayUnion([trail]),
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };
    }

    return {
      'status': 'approved',
      'managerApprovalIndex': managerIds.isEmpty ? 0 : managerIds.length - 1,
      'managerApprovalTrail': FieldValue.arrayUnion([trail]),
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    };
  }

  Future<void> submitAdvanceRequest(
    AdvanceModel req,
    UserModel employee,
  ) async {
    final now = DateTime.now();
    validateSubmissionEligibility(
      employee: employee,
      amount: req.amount,
      now: now,
    );
    final ref = _db.collection('advances').doc();
    final managerIds = _approvalManagerIds(employee, req.managerId);
    final managerNames = _approvalManagerNames(employee, employee.managerName);
    final newReq = AdvanceModel(
      advanceId: ref.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      amount: req.amount,
      reason: req.reason,
      status: 'pending_hr',
      monthKey: req.monthKey,
    );

    await ref.set({
      ...newReq.toFirestore(),
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
    });

    await AuditLogService.instance.record(
      actorId: employee.uid,
      action: 'advance_request_submitted',
      targetCollection: 'advances',
      targetId: ref.id,
    );

    await _notifyRole(
      role: EmployeeRole.hrAdmin,
      type: 'advance_pending_hr',
      title: 'طلب سلفة بانتظار HR',
      body:
          '${req.employeeName} يطلب سلفة بقيمة ${req.amount.toStringAsFixed(2)} ${employee.salaryCurrency}.',
      data: {'advanceId': ref.id},
    );
  }

  Stream<List<AdvanceModel>> watchMyAdvances(String userId) {
    return _db
        .collection('advances')
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(AdvanceModel.fromFirestore).toList();
        });
  }

  Stream<List<AdvanceModel>> watchTeamAdvances(UserModel reviewer) {
    Query<Map<String, dynamic>> query = _db.collection('advances');

    final reviewerCode = reviewer.employeeId.trim().toUpperCase();
    final isCompanyCeo = reviewer.isCompanyCeo || reviewerCode == 'CEO-100';
    final isCompanyCoo = reviewer.isCompanyCoo || reviewerCode == 'COO-1300';
    final isExecutive =
        isCompanyCeo || isCompanyCoo || reviewer.role == EmployeeRole.superAdmin;

    if (!isExecutive && reviewer.role == EmployeeRole.manager) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    }

    return query.orderBy('submittedAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map(AdvanceModel.fromFirestore).toList();
    });
  }

  Future<void> updateAdvanceStatus({
    required String advanceId,
    required String status,
    required String reviewerId,
    String? comment,
  }) async {
    final docRef = _db.collection('advances').doc(advanceId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('طلب السلفة غير موجود');
    final advance = AdvanceModel.fromFirestore(doc);

    await docRef.update({
      'status': status,
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (comment != null) 'reviewerComment': comment,
      'isRead': false,
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'advance_request_reviewed',
      targetCollection: 'advances',
      targetId: advanceId,
      metadata: {'newStatus': status},
    );

    if (status == 'approved' || status == 'rejected') {
      try {
        await _createNotification(
          recipientId: advance.userId,
          type: status == 'approved' ? 'advance_approved' : 'advance_rejected',
          title:
              status == 'approved'
                  ? 'تم قبول طلب السلفة ✅'
                  : 'تم رفض طلب السلفة ❌',
          body:
              status == 'approved'
                  ? 'تمت الموافقة على طلب السلفة بقيمة ${advance.amount.toStringAsFixed(2)}.'
                  : 'تم رفض طلب السلفة${comment == null || comment.trim().isEmpty ? "." : ". السبب: ${comment.trim()}"}',
          data: {'advanceId': advanceId},
        );
      } catch (_) {}
    }
  }

  Future<void> approveAdvanceRequest({
    required String advanceId,
    required UserModel reviewer,
  }) async {
    final docRef = _db.collection('advances').doc(advanceId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('طلب السلفة غير موجود');
    final advance = AdvanceModel.fromFirestore(doc);
    final data = doc.data() ?? <String, dynamic>{};
    final reviewerCode = reviewer.employeeId.trim().toUpperCase();
    final isCompanyCeo = reviewer.isCompanyCeo || reviewerCode == 'CEO-100';
    final isCompanyCoo = reviewer.isCompanyCoo || reviewerCode == 'COO-1300';
    final isExecutive =
        isCompanyCeo ||
        isCompanyCoo ||
        reviewer.role == EmployeeRole.superAdmin;
    final isMatchingManager =
        advance.managerId == reviewer.uid ||
        (reviewerCode.isNotEmpty && advance.managerId == reviewerCode) ||
        (data['managerCodes'] as List<dynamic>?)?.contains(reviewerCode) ==
            true ||
        (data['managerIds'] as List<dynamic>?)?.contains(reviewer.uid) ==
            true ||
        isExecutive;

    Map<String, dynamic> update;
    if ((EmployeeRole.isHr(reviewer.role) || isExecutive) &&
        advance.status == 'pending_hr') {
      final ceo = await _findAssignedCeo(advance.userId);
      update = {
        'status': 'pending_manager',
        'managerId': ceo.uid,
        'managerName': ceo.displayName,
        'managerApprovalIndex': 0,
        'advanceRouteStage': 'ceo',
        'approvalHistory': FieldValue.arrayUnion([
          _routeEvent('hr', reviewer, 'approved'),
        ]),
        'reviewedBy': reviewer.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };
    } else if (data['advanceRouteStage'] == 'ceo' &&
        (advance.managerId == reviewer.uid ||
            advance.managerId == 'CEO-100' ||
            isCompanyCeo)) {
      final accountant = await _findAdvanceAccountant();
      update = {
        'status': 'pending_manager',
        'managerId': accountant.uid,
        'managerName': accountant.displayName,
        'advanceRouteStage': 'accounting',
        'reviewedBy': reviewer.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'approvalHistory': FieldValue.arrayUnion([
          _routeEvent('ceo', reviewer, 'approved'),
        ]),
      };
    } else if (data['advanceRouteStage'] == 'accounting' &&
        (advance.managerId == reviewer.uid || isExecutive)) {
      update = {
        'status': 'approved',
        'advanceRouteStage': 'completed',
        'reviewedBy': reviewer.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'approvalHistory': FieldValue.arrayUnion([
          _routeEvent('accounting', reviewer, 'approved'),
        ]),
      };
    } else {
      if (!isMatchingManager) {
        throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
      }
      update = _nextManagerApprovalUpdate(
        data: data,
        reviewerId: reviewer.uid,
        reviewerRole: reviewer.role,
      );
    }

    await docRef.update(update);

    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'advance_request_reviewed',
      targetCollection: 'advances',
      targetId: advanceId,
      metadata: {'newStatus': update['status']},
    );

    final nextStatus = update['status'] as String? ?? '';
    if (nextStatus == 'pending_manager') {
      final nextManagerId = update['managerId'] as String? ?? '';
      if (nextManagerId.isNotEmpty) {
        try {
          await _createNotification(
            recipientId: nextManagerId,
            type:
                data['advanceRouteStage'] == 'ceo'
                    ? 'advance_pending_accounting'
                    : 'advance_pending_ceo',
            title: 'طلب سلفة بانتظار موافقتك',
            body:
                data['advanceRouteStage'] == 'ceo'
                    ? '${advance.employeeName} حصل على موافقة CEO وينتظر اعتماد الحسابات.'
                    : '${advance.employeeName} حصل على موافقة HR وينتظر قرار الرئيس التنفيذي.',
            data: {'advanceId': advanceId},
          );
        } catch (_) {}
      }
      return;
    }

    if (nextStatus == 'approved') {
      try {
        await _createNotification(
          recipientId: advance.userId,
          type: 'advance_approved',
          title: 'تم قبول طلب السلفة ✅',
          body:
              'تمت الموافقة على طلب السلفة بقيمة ${advance.amount.toStringAsFixed(2)}.',
          data: {'advanceId': advanceId},
        );
      } catch (_) {}
    }
  }

  Map<String, dynamic> _routeEvent(
    String stage,
    UserModel reviewer,
    String action,
  ) => {
    'stage': stage,
    'status': action,
    'actorId': reviewer.uid,
    'actorName': reviewer.displayName,
    'at': Timestamp.now(),
  };

  Future<UserModel> _findAssignedCeo(String employeeUid) async {
    var nextIds = <String>[employeeUid];
    final seen = <String>{};
    for (var depth = 0; depth < 12 && nextIds.isNotEmpty; depth++) {
      final current = nextIds.removeAt(0);
      if (!seen.add(current)) continue;
      final doc = await _db.collection('users').doc(current).get();
      if (!doc.exists) continue;
      final user = UserModel.fromFirestore(doc);
      final isCeo = user.employeeId.trim().toUpperCase().startsWith('CEO-');
      final canApproveAdvance =
          doc.data()?['isAdvanceCeoApprover'] == true ||
          user.role == EmployeeRole.manager;
      if (isCeo && canApproveAdvance) return user;
      nextIds.addAll(user.managerIds.where((id) => id.isNotEmpty));
      final directManagerId = user.managerId;
      if (directManagerId != null && directManagerId.isNotEmpty) {
        nextIds.add(directManagerId);
      }
    }
    throw StateError(
      'لا يمكن تحديد CEO مفعّل لمسار سلفة الموظف. اربط الموظف بـ CEO وفعّل isAdvanceCeoApprover عند الحاجة.',
    );
  }

  Future<UserModel> _findAdvanceAccountant() async {
    final snapshot =
        await _db
            .collection('users')
            .where('isActive', isEqualTo: true)
            .limit(500)
            .get();
    // Finance approval is an explicit role assignment, not an inferred
    // department. A department rename must never silently reroute money.
    final candidates =
        snapshot.docs
            .where((doc) => doc.data()['isAdvanceAccountsApprover'] == true)
            .map(UserModel.fromFirestore)
            .toList()
          ..sort((a, b) => a.employeeId.compareTo(b.employeeId));
    if (candidates.isEmpty) {
      throw StateError(
        'لا يوجد مسؤول حسابات مفعّل لمسار السلف. فعّل isAdvanceAccountsApprover لحساب المحاسب.',
      );
    }
    return candidates.first;
  }

  Future<void> markAsRead(String advanceId) async {
    await _db.collection('advances').doc(advanceId).update({'isRead': true});
  }

  Future<void> _createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await RoleNotificationService.instance.createNotification(
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      data: data,
    );
  }

  Future<void> _notifyRole({
    required String role,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await RoleNotificationService.instance.notifyRole(
      role: role,
      type: type,
      title: title,
      body: body,
      data: data,
    );
  }
}
