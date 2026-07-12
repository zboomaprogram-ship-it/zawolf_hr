import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/advance_model.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';
import 'audit_log_service.dart';
import 'role_notification_service.dart';

class AdvanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<String> _approvalManagerIds(UserModel employee, String fallbackId) {
    final ids = employee.managerIds
        .where((id) => id.trim().isNotEmpty)
        .toList();
    if (ids.isNotEmpty) return ids;
    return fallbackId.trim().isEmpty ? <String>[] : <String>[fallbackId];
  }

  List<String> _approvalManagerNames(UserModel employee, String? fallbackName) {
    final names = employee.managerNames
        .where((name) => name.trim().isNotEmpty)
        .toList();
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
        'managerName': nextIndex < managerNames.length
            ? managerNames[nextIndex]
            : null,
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

    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
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
          title: status == 'approved'
              ? 'تم قبول طلب السلفة ✅'
              : 'تم رفض طلب السلفة ❌',
          body: status == 'approved'
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

    Map<String, dynamic> update;
    if ((reviewer.role == EmployeeRole.hrAdmin ||
            reviewer.role == EmployeeRole.superAdmin) &&
        advance.status == 'pending_hr') {
      final managerIds =
          (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          (advance.managerId.isEmpty
              ? <String>[]
              : <String>[advance.managerId]);
      final managerNames =
          (data['managerNames'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          <String>[];
      final firstManagerId = managerIds.isNotEmpty ? managerIds.first : '';
      update = {
        'status': firstManagerId.isEmpty ? 'approved' : 'pending_manager',
        if (firstManagerId.isNotEmpty) 'managerId': firstManagerId,
        if (managerNames.isNotEmpty) 'managerName': managerNames.first,
        'managerApprovalIndex': 0,
        'reviewedBy': reviewer.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };
    } else {
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
            type: 'advance_pending_manager',
            title: 'طلب سلفة بانتظار موافقتك',
            body: '${advance.employeeName} حصل على موافقة HR وينتظر قرارك.',
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
    await RoleNotificationService.instance.notifyRole(
      role: role,
      type: type,
      title: title,
      body: body,
      data: data,
    );
  }
}
