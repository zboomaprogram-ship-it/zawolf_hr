import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/manager_approval_chain.dart';
import '../models/resignation_model.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';
import 'role_notification_service.dart';

class ResignationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ResignationModel>> watchMine(String userId) {
    return _db
        .collection('resignations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final values = snapshot.docs
              .map(ResignationModel.fromFirestore)
              .toList();
          values.sort(
            (a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(
              a.submittedAt ?? DateTime(2000),
            ),
          );
          return values;
        });
  }

  Stream<List<ResignationModel>> watchPending(UserModel reviewer) {
    Query<Map<String, dynamic>> query = _db.collection('resignations');
    if (reviewer.role == EmployeeRole.hrManager) {
      query = query.where('status', isEqualTo: 'pending_hr');
    } else {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(ResignationModel.fromFirestore).toList(),
    );
  }

  Future<void> submit({
    required UserModel employee,
    required String reason,
    required DateTime resignationDate,
  }) async {
    final cleanReason = reason.trim();
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (cleanReason.isEmpty) throw Exception('يجب كتابة سبب الاستقالة.');
    if (resignationDate.isBefore(todayOnly)) {
      throw Exception('تاريخ الاستقالة لا يمكن أن يكون في الماضي.');
    }

    final managerIds = ManagerApprovalChain.orderedIds(
      employee.managerIds,
      fallbackId: employee.managerId,
      teamLeaderId: employee.teamLeaderId,
    );
    final managerNames = ManagerApprovalChain.orderedNames(
      orderedIds: managerIds,
      managerIds: employee.managerIds,
      managerNames: employee.managerNames,
      teamLeaderId: employee.teamLeaderId,
      teamLeaderName: employee.teamLeaderName,
      fallbackManagerId: employee.managerId,
      fallbackManagerName: employee.managerName,
    );
    final ref = _db.collection('resignations').doc();
    final firstManagerId = managerIds.isEmpty ? '' : managerIds.first;
    await ref.set({
      'userId': employee.uid,
      'employeeId': employee.employeeId,
      'employeeName': employee.displayName,
      'department': employee.department,
      'reason': cleanReason,
      'resignationDate': Timestamp.fromDate(resignationDate),
      'status': managerIds.isEmpty ? 'pending_hr' : 'pending_manager',
      'managerId': firstManagerId,
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'submittedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    if (managerIds.isEmpty) {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrManager,
        includeSuperAdmins: false,
        type: 'resignation_pending_hr',
        title: 'طلب استقالة جديد',
        body: '${employee.displayName} قدّم طلب استقالة.',
        data: {'resignationId': ref.id},
      );
    } else {
      await RoleNotificationService.instance.createNotification(
        recipientId: firstManagerId,
        type: 'resignation_pending_manager',
        title: 'طلب استقالة بانتظار موافقتك',
        body: '${employee.displayName} قدّم طلب استقالة.',
        data: {'resignationId': ref.id},
      );
    }
  }

  Future<void> review({
    required String resignationId,
    required UserModel reviewer,
    required bool approve,
    String comment = '',
  }) async {
    final ref = _db.collection('resignations').doc(resignationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw Exception('طلب الاستقالة غير موجود.');
    final request = ResignationModel.fromFirestore(snapshot);

    if (request.status == 'pending_hr') {
      if (reviewer.role != EmployeeRole.hrManager) {
        throw Exception('القرار النهائي للاستقالة متاح لمدير HR فقط.');
      }
      await ref.update({
        'status': approve ? 'approved' : 'rejected',
        'reviewedBy': reviewer.uid,
        'reviewerName': reviewer.displayName,
        'reviewerComment': comment.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'isRead': true,
      });
    } else {
      if (request.status != 'pending_manager' ||
          request.managerId != reviewer.uid) {
        throw Exception('هذا الطلب ليس في مرحلة موافقتك.');
      }
      final nextIndex = request.managerApprovalIndex + 1;
      final hasNext = approve && nextIndex < request.managerIds.length;
      final nextStatus = !approve
          ? 'rejected'
          : (hasNext ? 'pending_manager' : 'pending_hr');
      await ref.update({
        'status': nextStatus,
        if (hasNext) 'managerId': request.managerIds[nextIndex],
        if (hasNext && nextIndex < request.managerNames.length)
          'managerName': request.managerNames[nextIndex],
        if (hasNext) 'managerApprovalIndex': nextIndex,
        'managerApprovalTrail': FieldValue.arrayUnion([
          {
            'reviewerId': reviewer.uid,
            'reviewerName': reviewer.displayName,
            'reviewedAt': Timestamp.now(),
            'approved': approve,
          },
        ]),
        'reviewedBy': reviewer.uid,
        'reviewerName': reviewer.displayName,
        'reviewerComment': comment.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (hasNext) {
        await RoleNotificationService.instance.createNotification(
          recipientId: request.managerIds[nextIndex],
          type: 'resignation_pending_manager',
          title: 'طلب استقالة بانتظار موافقتك',
          body: '${request.employeeName} قدّم طلب استقالة.',
          data: {'resignationId': resignationId},
        );
      } else if (approve) {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrManager,
          includeSuperAdmins: false,
          type: 'resignation_pending_hr',
          title: 'طلب استقالة بانتظار القرار النهائي',
          body: 'اكتملت موافقات المديرين على طلب ${request.employeeName}.',
          data: {'resignationId': resignationId},
        );
      }
    }

    await RoleNotificationService.instance.createNotification(
      recipientId: request.userId,
      type: approve ? 'resignation_reviewed' : 'resignation_rejected',
      title: approve ? 'تم تحديث طلب الاستقالة' : 'تم رفض طلب الاستقالة',
      body: approve
          ? 'تمت الموافقة على المرحلة الحالية من طلب الاستقالة.'
          : 'سبب الرفض: ${comment.trim()}',
      data: {'resignationId': resignationId},
    );
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: approve ? 'resignation_approved' : 'resignation_rejected',
      targetCollection: 'resignations',
      targetId: resignationId,
      metadata: {'userId': request.userId, 'comment': comment.trim()},
    );
  }
}
