import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/administrative_request_model.dart';
import '../models/employee_role.dart';
import '../models/manager_approval_chain.dart';
import '../models/notification_route_policy.dart';
import '../models/user_model.dart';
import 'role_notification_service.dart';

class AdministrativeRequestService {
  AdministrativeRequestService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMine(String userId) {
    return _db
        .collection('administrativeRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPending(UserModel reviewer) {
    if (EmployeeRole.isHrStaff(reviewer.role)) {
      return _db
          .collection('administrativeRequests')
          .where('status', whereIn: ['pending_hr', 'pending_manager'])
          .snapshots();
    }
    return _db
        .collection('administrativeRequests')
        .where('status', isEqualTo: 'pending_manager')
        .where('managerId', isEqualTo: reviewer.uid)
        .snapshots();
  }

  Future<void> approve(String requestId, UserModel reviewer) async {
    final ref = _db.collection('administrativeRequests').doc(requestId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw Exception('الطلب الإداري غير موجود.');
    final data = snapshot.data()!;
    final status = data['status'] as String? ?? '';
    if (status == 'pending_hr') {
      if (!EmployeeRole.isHrStaff(reviewer.role)) {
        throw Exception('هذه المرحلة خاصة بالموارد البشرية.');
      }
      await ref.update({
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
      await _notify(
        data['userId'] as String,
        'تم قبول الطلب الإداري',
        'تمت الموافقة على ${data['categoryLabel']}.',
        requestId,
      );
      return;
    }
    if (status != 'pending_manager' || data['managerId'] != reviewer.uid) {
      throw Exception('هذا الطلب ينتظر مراجعاً آخر.');
    }
    final ids = (data['managerIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final names = (data['managerNames'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final index = (data['managerApprovalIndex'] as num?)?.toInt() ?? 0;
    final next = index + 1;
    final nextStatus = next < ids.length ? 'pending_manager' : 'pending_hr';
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
    });
    if (next < ids.length) {
      await _notify(
        ids[next],
        'طلب إداري بانتظار موافقتك',
        '${data['employeeName']} حصل على موافقة سابقة.',
        requestId,
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
    final allowed =
        (status == 'pending_manager' && data['managerId'] == reviewer.uid) ||
        (status == 'pending_hr' && EmployeeRole.isHrStaff(reviewer.role));
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
          stage: status == 'pending_hr' ? 'hr' : 'manager',
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
    final ref = _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .doc();
    await ref.set({
      'notificationId': ref.id,
      'type': 'administrative_request_update',
      'title': title,
      'body': body,
      'data': NotificationRoutePolicy.dataWithRoute(
        'administrative_request_update',
        {'administrativeRequestId': requestId, 'route': '/employee/requests'},
      ),
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
