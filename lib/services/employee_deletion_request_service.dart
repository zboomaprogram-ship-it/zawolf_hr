import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_deletion_request.dart';
import '../models/employee_role.dart';
import '../models/user_model.dart';
import 'role_notification_service.dart';

class EmployeeDeletionRequestService {
  final FirebaseFirestore _db;

  EmployeeDeletionRequestService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Stream<List<EmployeeDeletionRequest>> watchPending() {
    return _db.collection('employeeDeletionRequests').snapshots().map((snap) {
      final requests = snap.docs
          .map(EmployeeDeletionRequest.fromDocument)
          .where(
            (item) =>
                item.status == 'pending_hr_manager' ||
                item.status == 'pending_super_admin',
          )
          .toList();
      requests.sort(
        (a, b) => (b.requestedAt ?? DateTime(1970)).compareTo(
          a.requestedAt ?? DateTime(1970),
        ),
      );
      return requests;
    });
  }

  Future<void> requestDeletion({
    required UserModel employee,
    required UserModel requester,
    required String reason,
  }) async {
    if (employee.uid == requester.uid) {
      throw StateError('لا يمكنك طلب حذف حسابك من هذه الشاشة.');
    }

    // Only Admin (Super Admin) can delete/deactivate user directly without sending a request
    if (requester.role == EmployeeRole.superAdmin) {
      final employeeRef = _db.collection('users').doc(employee.uid);
      await employeeRef.update({
        'isActive': false,
        'deactivationReason': reason.trim(),
        'deactivatedBy': requester.uid,
        'deactivatedByName': requester.displayName,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear/Approve any pending deletion requests for this user
      final existing = await _db
          .collection('employeeDeletionRequests')
          .where('employeeId', isEqualTo: employee.uid)
          .get();
      for (final doc in existing.docs) {
        final st = doc.data()['status'];
        if (st == 'pending_hr_manager' || st == 'pending_super_admin') {
          await doc.reference.update({
            'status': 'approved',
            'approvedBy': requester.uid,
            'approvedByName': requester.displayName,
            'reviewedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return;
    }

    if (employee.role == EmployeeRole.superAdmin ||
        employee.role == EmployeeRole.hrManager ||
        employee.role == EmployeeRole.hrAdmin) {
      throw StateError('الحسابات العليا تحتاج إجراءً إداريًا منفصلًا.');
    }
    final existing = await _db
        .collection('employeeDeletionRequests')
        .where('employeeId', isEqualTo: employee.uid)
        .get();
    if (existing.docs.any((doc) {
      final status = doc.data()['status'];
      return status == 'pending_hr_manager' || status == 'pending_super_admin';
    })) {
      throw StateError('يوجد طلب حذف معلق لهذا الموظف بالفعل.');
    }
    final status = requester.role == EmployeeRole.hrManager
        ? 'pending_super_admin'
        : 'pending_hr_manager';
    final ref = _db.collection('employeeDeletionRequests').doc();
    await ref.set({
      'employeeId': employee.uid,
      'employeeCode': employee.employeeId,
      'employeeName': employee.displayName,
      'requesterId': requester.uid,
      'requesterName': requester.displayName,
      'requesterRole': requester.role,
      'reason': reason,
      'status': status,
      'approvalHistory': [
        {
          'action': 'submitted',
          'actorId': requester.uid,
          'actorName': requester.displayName,
          'actorRole': requester.role,
          'at': Timestamp.now(),
        },
      ],
      'requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await RoleNotificationService.instance.notifyRole(
      role: status == 'pending_hr_manager'
          ? EmployeeRole.hrManager
          : EmployeeRole.superAdmin,
      type: 'employee_deletion_pending',
      title: 'طلب إنهاء حساب موظف',
      body: 'طلب ${requester.displayName} إنهاء حساب ${employee.displayName}.',
      data: {'requestId': ref.id, 'route': '/hr/employees'},
      includeSuperAdmins: status == 'pending_super_admin',
    );
  }

  Future<void> review({
    required EmployeeDeletionRequest request,
    required UserModel reviewer,
    required bool approve,
  }) async {
    if (request.requesterId == reviewer.uid) {
      throw StateError('لا يمكن لمقدم الطلب اعتماد طلبه.');
    }
    final isHrStage = request.status == 'pending_hr_manager';
    if (isHrStage && reviewer.role != EmployeeRole.hrManager) {
      throw StateError('هذه المرحلة تحتاج موافقة مدير HR.');
    }
    if (!isHrStage && reviewer.role != EmployeeRole.superAdmin) {
      throw StateError('هذه المرحلة تحتاج موافقة مالك النظام.');
    }
    final requestRef = _db
        .collection('employeeDeletionRequests')
        .doc(request.id);
    final employeeRef = _db.collection('users').doc(request.employeeId);
    var forwardedForFinalApproval = false;
    var accountDeactivated = false;
    await _db.runTransaction((transaction) async {
      final fresh = await transaction.get(requestRef);
      final data = fresh.data();
      if (data == null || data['status'] != request.status) {
        throw StateError('تمت معالجة الطلب بالفعل.');
      }
      if (!approve) {
        transaction.update(requestRef, {
          'status': 'rejected',
          'rejectedBy': reviewer.uid,
          'rejectedByName': reviewer.displayName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'action': 'rejected',
              'actorId': reviewer.uid,
              'actorName': reviewer.displayName,
              'actorRole': reviewer.role,
              'at': Timestamp.now(),
            },
          ]),
        });
        return;
      }
      final requesterRole = data['requesterRole'] as String? ?? '';
      final hrApprovalIsFinal =
          isHrStage && requesterRole == EmployeeRole.superAdmin;
      if (isHrStage && !hrApprovalIsFinal) {
        forwardedForFinalApproval = true;
        transaction.update(requestRef, {
          'status': 'pending_super_admin',
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'action': 'approved_hr_manager',
              'actorId': reviewer.uid,
              'actorName': reviewer.displayName,
              'actorRole': reviewer.role,
              'at': Timestamp.now(),
            },
          ]),
        });
      } else {
        accountDeactivated = true;
        transaction.update(requestRef, {
          'status': 'approved',
          'approvedBy': reviewer.uid,
          'approvedByName': reviewer.displayName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            {
              'action': hrApprovalIsFinal
                  ? 'approved_final_hr_manager'
                  : 'approved_final',
              'actorId': reviewer.uid,
              'actorName': reviewer.displayName,
              'actorRole': reviewer.role,
              'at': Timestamp.now(),
            },
          ]),
        });
        transaction.update(employeeRef, {
          'isActive': false,
          'deactivationReason': request.reason,
          'deactivatedBy': reviewer.uid,
          'deactivatedByName': reviewer.displayName,
          'deactivatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // Delivery is best effort. The Firestore transaction remains the source of
    // truth and must not fail because a push notification cannot be created.
    if (!approve) {
      await _notifyRequester(
        request,
        type: 'employee_deletion_rejected',
        title: 'تم رفض طلب إنهاء الحساب',
        body: 'تم رفض طلب إنهاء حساب ${request.employeeName}.',
      );
    } else if (forwardedForFinalApproval) {
      await RoleNotificationService.instance.notifyRole(
        role: EmployeeRole.superAdmin,
        type: 'employee_deletion_pending',
        title: 'طلب إنهاء حساب بانتظار الاعتماد النهائي',
        body: 'تمت موافقة مدير HR على إنهاء حساب ${request.employeeName}.',
        data: {'requestId': request.id, 'route': '/hr/employees'},
        includeSuperAdmins: true,
      );
    } else if (accountDeactivated) {
      await _notifyRequester(
        request,
        type: 'employee_deletion_approved',
        title: 'تم إنهاء الحساب',
        body: 'تم اعتماد إنهاء حساب ${request.employeeName} وإيقافه.',
      );
    }
  }

  Future<void> _notifyRequester(
    EmployeeDeletionRequest request, {
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      await RoleNotificationService.instance.createNotification(
        recipientId: request.requesterId,
        type: type,
        title: title,
        body: body,
        data: {'requestId': request.id, 'route': '/hr/employees'},
      );
    } catch (_) {
      // The review itself is already committed and must remain successful.
    }
  }
}
