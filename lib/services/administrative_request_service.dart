import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/administrative_request_model.dart';
import '../models/employee_role.dart';
import '../models/manager_approval_chain.dart';
import '../models/user_model.dart';
import '../features/request_approval_routing/data/request_approval_routing_gateway.dart';
import 'role_notification_service.dart';

class AdministrativeRequestService {
  AdministrativeRequestService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final RequestApprovalRoutingGateway _routingGateway =
      RequestApprovalRoutingGateway();

  Map<String, dynamic> _event({
    required String stage,
    required String status,
    required String actorId,
    required String actorName,
    String? comment,
  }) => {
    'stage': stage,
    'status': status,
    'actorId': actorId,
    'actorName': actorName,
    'timestamp': Timestamp.now(),
    if ((comment ?? '').isNotEmpty) 'comment': comment,
  };

  Future<void> submit({
    required UserModel employee,
    required String category,
    required String notes,
    String? attachmentUrl,
  }) async {
    if (!AdministrativeRequestCategory.values.contains(category)) {
      throw Exception('نوع الطلب الإداري غير صالح.');
    }
    if (notes.trim().isEmpty) throw Exception('تفاصيل الطلب مطلوبة.');
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
    final usesHrFallback = ManagerApprovalChain.usesHrFallback(
      isSuperAdmin: employee.role == EmployeeRole.superAdmin,
      managerIds: managerIds,
    );
    if (managerIds.isEmpty && !usesHrFallback) {
      throw Exception('يجب تعيين مدير قبل إرسال الطلب الإداري.');
    }
    final ref = _db.collection('administrativeRequests').doc();
    await ref.set({
      'userId': employee.uid,
      'employeeId': employee.employeeId,
      'employeeName': employee.displayName,
      'department': employee.department,
      'category': category,
      'categoryLabel': AdministrativeRequestCategory.arabicLabel(category),
      'notes': notes.trim(),
      'attachmentUrl': attachmentUrl?.trim(),
      'status': usesHrFallback ? 'pending_hr' : 'pending_manager',
      'managerId': managerIds.isEmpty ? '' : managerIds.first,
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'approvalHistory': [
        _event(
          stage: 'submitted',
          status: 'completed',
          actorId: employee.uid,
          actorName: employee.displayName,
        ),
      ],
      'submittedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    if (usesHrFallback) {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.hrManager,
        includeSuperAdmins: false,
        type: 'administrative_request_submitted',
        title: 'طلب إداري جديد',
        body: '${employee.displayName} أرسل طلباً إدارياً.',
        data: {'administrativeRequestId': ref.id},
      );
    } else {
      await _notify(
        managerIds.first,
        'طلب إداري بانتظار موافقتك',
        '${employee.displayName}: ${AdministrativeRequestCategory.arabicLabel(category)}',
        ref.id,
      );
    }
  }

  Future<void> submitFieldMission({
    required UserModel employee,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String siteName,
    required String reason,
    required bool requiresReturnToOffice,
    required bool requiresCheckout,
  }) async {
    if (siteName.trim().isEmpty || reason.trim().isEmpty) {
      throw Exception('مكان المهمة وسببها مطلوبان.');
    }
    if (startTime.compareTo(endTime) >= 0) {
      throw Exception('وقت نهاية المهمة يجب أن يكون بعد وقت البداية.');
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
    final usesHrFallback = ManagerApprovalChain.usesHrFallback(
      isSuperAdmin: employee.role == EmployeeRole.superAdmin,
      managerIds: managerIds,
    );
    if (managerIds.isEmpty && !usesHrFallback) {
      throw Exception('يجب تعيين مدير قبل إرسال المأمورية.');
    }
    final ref = _db.collection('administrativeRequests').doc();
    await ref.set({
      'userId': employee.uid,
      'employeeId': employee.employeeId,
      'employeeName': employee.displayName,
      'department': employee.department,
      'category': AdministrativeRequestCategory.fieldMission,
      'categoryLabel': AdministrativeRequestCategory.arabicLabel(
        AdministrativeRequestCategory.fieldMission,
      ),
      'notes': reason.trim(),
      'missionDate': DateFormat('yyyy-MM-dd').format(date),
      'startTime': startTime,
      'endTime': endTime,
      'siteName': siteName.trim(),
      'requiresReturnToOffice': requiresReturnToOffice,
      'requiresCheckout': requiresCheckout,
      'status': usesHrFallback ? 'pending_hr' : 'pending_manager',
      'managerId': managerIds.isEmpty ? '' : managerIds.first,
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'approvalHistory': [
        _event(
          stage: 'submitted',
          status: 'completed',
          actorId: employee.uid,
          actorName: employee.displayName,
        ),
      ],
      'submittedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    try {
      if (usesHrFallback) {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrManager,
          includeSuperAdmins: false,
          type: 'administrative_request_submitted',
          title: 'مهمة ميدانية جديدة',
          body: '${employee.displayName} أرسل طلب مهمة ميدانية.',
          data: {'administrativeRequestId': ref.id},
        );
      } else {
        await _notify(
          managerIds.first,
          'مهمة ميدانية بانتظار موافقتك',
          '${employee.displayName}: مهمة ميدانية في ${siteName.trim()}',
          ref.id,
        );
      }
    } catch (e) {
      debugPrint('Failed to dispatch field mission notification: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMine(String userId) {
    return _db
        .collection('administrativeRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .limit(25)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPending(UserModel reviewer) {
    final isCeo = reviewer.canReviewCeoStage;
    if (isCeo) {
      return _db
          .collection('administrativeRequests')
          .where(
            'status',
            whereIn: ['pending_manager', 'pending_ceo', 'pending_hr'],
          )
          .limit(100)
          .snapshots();
    }
    if (EmployeeRole.isHr(reviewer.role)) {
      return _db
          .collection('administrativeRequests')
          .where('status', whereIn: ['pending_hr', 'pending_manager'])
          .limit(100)
          .snapshots();
    }
    return _db
        .collection('administrativeRequests')
        .where('status', isEqualTo: 'pending_manager')
        .where('managerId', isEqualTo: reviewer.uid)
        .limit(100)
        .snapshots();
  }

  Future<void> approve(String requestId, UserModel reviewer) async {
    final ref = _db.collection('administrativeRequests').doc(requestId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw Exception('الطلب الإداري غير موجود.');
    final data = snapshot.data()!;
    final status = data['status'] as String? ?? '';
    if (data['approvalRouteVersion'] == 1) {
      await _routingGateway.decideFieldMission(
        requestId: requestId,
        approved: true,
      );
      return;
    }
    final isFieldMission =
        data['category'] == AdministrativeRequestCategory.fieldMission;
    if (status == 'pending_ceo') {
      final isCeo = reviewer.canReviewCeoStage;
      final ceoId = (data['ceoId'] ?? '').toString();
      if (!isCeo ||
          (ceoId.isNotEmpty && ceoId != reviewer.uid && ceoId != 'CEO-100')) {
        throw Exception('هذه المرحلة متاحة لحساب CEO-100 فقط.');
      }
      await ref.update({
        'status': 'pending_hr',
        'reviewedBy': reviewer.uid,
        'reviewerName': reviewer.displayName,
        'reviewedAt': FieldValue.serverTimestamp(),
        'approvalHistory': FieldValue.arrayUnion([
          _event(
            stage: 'ceo',
            status: 'approved',
            actorId: reviewer.uid,
            actorName: reviewer.displayName,
          ),
        ]),
      });
      try {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrAdmin,
          includeSuperAdmins: false,
          type: 'administrative_request_submitted',
          title: 'مهمة ميدانية بانتظار اعتماد HR',
          body: 'اعتمد CEO-100 مهمة ${data['employeeName']}.',
          data: {'administrativeRequestId': requestId},
        );
      } catch (e) {
        debugPrint('Failed to send CEO approval notification: $e');
      }
      return;
    }
    if (status == 'pending_hr') {
      if (!EmployeeRole.isHr(reviewer.role)) {
        throw Exception('هذه المرحلة خاصة بالموارد البشرية.');
      }
      final batch = _db.batch();
      batch.update(ref, {
        'status': 'approved',
        'reviewedBy': reviewer.uid,
        'reviewerName': reviewer.displayName,
        'reviewedAt': FieldValue.serverTimestamp(),
        'finalApproverId': reviewer.uid,
        'finalApproverName': reviewer.displayName,
        'finalApprovalAt': FieldValue.serverTimestamp(),
        'approvalHistory': FieldValue.arrayUnion([
          _event(
            stage: 'hr',
            status: 'approved',
            actorId: reviewer.uid,
            actorName: reviewer.displayName,
          ),
        ]),
      });
      if (isFieldMission) {
        final assignmentRef = _db.collection('fieldAssignments').doc(requestId);
        batch.set(assignmentRef, {
          'userId': data['userId'],
          'employeeId': data['employeeId'],
          'employeeName': data['employeeName'],
          'department': data['department'],
          'locationId': data['locationId'] ?? '',
          'date': data['missionDate'],
          'startTime': data['startTime'],
          'endTime': data['endTime'],
          'reason': data['notes'],
          'siteName': data['siteName'],
          'requiresReturnToOffice': data['requiresReturnToOffice'] ?? true,
          'requiresCheckout': data['requiresCheckout'] ?? true,
          'status': 'active',
          'createdBy': reviewer.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await _notify(
        data['userId'] as String,
        'تم قبول الطلب الإداري',
        'تمت الموافقة على ${data['categoryLabel']}.',
        requestId,
      );
      return;
    }
    final isCeo = reviewer.canReviewCeoStage;
    if (status != 'pending_manager' ||
        (data['managerId'] != reviewer.uid && !isCeo)) {
      throw Exception('هذا الطلب ينتظر مراجعاً آخر.');
    }
    final ids =
        (data['managerIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    final names =
        (data['managerNames'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    final index = (data['managerApprovalIndex'] as num?)?.toInt() ?? 0;
    final next = index + 1;
    var nextStatus = next < ids.length ? 'pending_manager' : 'pending_hr';
    String? ceoId;
    String? ceoName;
    if (isFieldMission && next >= ids.length) {
      // Older CEO profiles stored the code in employeeCode rather than
      // employeeId. Resolve both shapes so CEO-100 is never skipped.
      final byEmployeeId =
          await _db
              .collection('users')
              .where('employeeId', isEqualTo: 'CEO-100')
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();
      final ceo =
          byEmployeeId.docs.isNotEmpty
              ? byEmployeeId
              : await _db
                  .collection('users')
                  .where('employeeCode', isEqualTo: 'CEO-100')
                  .where('isActive', isEqualTo: true)
                  .limit(1)
                  .get();
      if (ceo.docs.isEmpty) {
        throw Exception('لا يوجد حساب نشط بكود CEO-100.');
      }
      nextStatus = 'pending_ceo';
      ceoId = ceo.docs.first.id;
      ceoName = ceo.docs.first.data()['displayName'] as String? ?? 'CEO';
    }
    await ref.update({
      'status': nextStatus,
      if (next < ids.length) 'managerId': ids[next],
      if (next < names.length) 'managerName': names[next],
      'managerApprovalIndex': next < ids.length ? next : index,
      'managerApprovalTrail': FieldValue.arrayUnion([
        {
          'reviewerId': reviewer.uid,
          'reviewerName': reviewer.displayName,
          'reviewerRole': reviewer.role,
          'reviewedAt': Timestamp.now(),
          'timestamp': Timestamp.now(),
          'status': 'approved',
          'stage': index,
        },
      ]),
      'approvalHistory': FieldValue.arrayUnion([
        _event(
          stage: 'manager',
          status: 'approved',
          actorId: reviewer.uid,
          actorName: reviewer.displayName,
        ),
      ]),
      'reviewedBy': reviewer.uid,
      'reviewerName': reviewer.displayName,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (ceoId != null) 'ceoId': ceoId,
      if (ceoName != null) 'ceoName': ceoName,
    });
    try {
      if (next < ids.length) {
        await _notify(
          ids[next],
          'طلب إداري بانتظار موافقتك',
          '${data['employeeName']} حصل على موافقة سابقة.',
          requestId,
        );
      } else if (nextStatus == 'pending_ceo') {
        await RoleNotificationService.instance.createNotification(
          recipientId: ceoId!,
          type: 'field_mission_pending_ceo',
          title: 'مهمة ميدانية بانتظار اعتماد CEO',
          body: 'اكتملت موافقات المديرين على مهمة ${data['employeeName']}.',
          data: {'administrativeRequestId': requestId},
        );
      } else {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrAdmin,
          includeSuperAdmins: false,
          type: 'administrative_request_submitted',
          title: 'طلب إداري بانتظار HR',
          body: 'اكتملت موافقات المديرين على طلب ${data['employeeName']}.',
          data: {'administrativeRequestId': requestId},
        );
      }
    } catch (e) {
      debugPrint('Failed to send manager chain notification: $e');
    }
  }

  Future<void> reject(
    String requestId,
    UserModel reviewer,
    String reason,
  ) async {
    final ref = _db.collection('administrativeRequests').doc(requestId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw Exception('الطلب الإداري غير موجود.');
    final data = snapshot.data()!;
    final status = data['status'] as String? ?? '';
    if (data['approvalRouteVersion'] == 1) {
      await _routingGateway.decideFieldMission(
        requestId: requestId,
        approved: false,
        comment: reason,
      );
      return;
    }
    final isCeo = reviewer.canReviewCeoStage;
    final ceoId = (data['ceoId'] ?? '').toString();
    final allowed =
        (status == 'pending_manager' &&
            (data['managerId'] == reviewer.uid ||
                data['currentApproverId'] == reviewer.uid ||
                isCeo)) ||
        (status == 'pending_ceo' &&
            isCeo &&
            (ceoId.isEmpty || ceoId == reviewer.uid || ceoId == 'CEO-100')) ||
        (status == 'pending_hr' && EmployeeRole.isHr(reviewer.role));
    if (!allowed) throw Exception('غير مسموح بمراجعة هذا الطلب.');
    await ref.update({
      'status': 'rejected',
      'reviewedBy': reviewer.uid,
      'reviewerName': reviewer.displayName,
      'reviewerComment': reason.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'finalApproverId': reviewer.uid,
      'finalApproverName': reviewer.displayName,
      'finalApprovalAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([
        _event(
          stage:
              status == 'pending_hr'
                  ? 'hr'
                  : (status == 'pending_ceo' ? 'ceo' : 'manager'),
          status: 'rejected',
          actorId: reviewer.uid,
          actorName: reviewer.displayName,
          comment: reason.trim(),
        ),
      ]),
    });
    await _notify(
      data['userId'] as String,
      'تم رفض الطلب الإداري',
      'السبب: ${reason.trim()}',
      requestId,
    );
  }

  Future<void> _notify(
    String userId,
    String title,
    String body,
    String requestId,
  ) async {
    try {
      await RoleNotificationService.instance.createNotification(
        recipientId: userId,
        type: 'administrative_request_update',
        title: title,
        body: body,
        data: {
          'administrativeRequestId': requestId,
          'route': '/employee/requests',
        },
      );
    } catch (e) {
      debugPrint('Failed to send administrative notification to user: $e');
    }
  }
}
