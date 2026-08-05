import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/employee_role.dart';
import '../models/manual_deduction_model.dart';
import '../models/notification_route_policy.dart';
import '../models/user_model.dart';
import '../utils/payroll_cycle.dart';
import 'audit_log_service.dart';

class ManualDeductionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ManualDeductionModel>> watchAllDeductions() {
    return _db
        .collection('manual_deductions')
        .snapshots()
        .map((snap) => snap.docs.map(ManualDeductionModel.fromFirestore).toList());
  }

  Stream<List<ManualDeductionModel>> watchManagedDeductions(UserModel reviewer) {
    if (reviewer.role == EmployeeRole.superAdmin ||
        reviewer.role == EmployeeRole.hrAdmin ||
        reviewer.role == EmployeeRole.hrManager) {
      return watchAllDeductions();
    }

    return _db
        .collection('manual_deductions')
        .where('managerIds', arrayContains: reviewer.uid)
        .snapshots()
        .map((snap) => snap.docs.map(ManualDeductionModel.fromFirestore).toList());
  }

  Future<void> createDeductionRequest({
    required UserModel creator,
    required UserModel targetEmployee,
    required DateTime date,
    required double dayFraction,
    required String reason,
  }) async {
    final ref = _db.collection('manual_deductions').doc();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final monthKey = PayrollCycle.forDate(date).key;
    final fractionLabel = ManualDeductionModel.getFractionLabel(dayFraction);

    String status = 'pending_hr';
    String createdByRole = 'manager';

    if (creator.role == EmployeeRole.superAdmin) {
      status = 'approved';
      createdByRole = 'super_admin';
    } else if (creator.role == EmployeeRole.hrAdmin ||
        creator.role == EmployeeRole.hrManager) {
      createdByRole = 'hr';
      status = 'pending_manager';
    } else {
      createdByRole = 'manager';
      status = 'pending_hr';
    }

    final managerIds = <String>{
      ...targetEmployee.managerIds,
      if (targetEmployee.managerId?.isNotEmpty == true) targetEmployee.managerId!,
    }.toList();

    final model = ManualDeductionModel(
      id: ref.id,
      userId: targetEmployee.uid,
      employeeName: targetEmployee.displayName,
      employeeId: targetEmployee.employeeId,
      department: targetEmployee.department,
      managerId: targetEmployee.managerId ?? '',
      managerIds: managerIds,
      createdBy: creator.uid,
      createdByName: creator.displayName,
      createdByRole: createdByRole,
      date: date,
      dateKey: dateKey,
      monthKey: monthKey,
      dayFraction: dayFraction,
      fractionLabel: fractionLabel,
      reason: reason.trim(),
      status: status,
      createdAt: DateTime.now(),
      approvedBy: status == 'approved' ? creator.uid : null,
      approvedByName: status == 'approved' ? creator.displayName : null,
      approvedAt: status == 'approved' ? DateTime.now() : null,
    );

    await ref.set(model.toFirestore());

    await AuditLogService.instance.record(
      actorId: creator.uid,
      action: 'manual_deduction_created',
      targetCollection: 'manual_deductions',
      targetId: ref.id,
      metadata: {
        'targetUserId': targetEmployee.uid,
        'dayFraction': dayFraction,
        'reason': reason,
        'status': status,
      },
    );

    // Send notification to the reviewer or employee
    if (status == 'pending_manager') {
      for (final mgrId in managerIds) {
        await _sendNotification(
          recipientId: mgrId,
          type: 'salary_deduction_pending',
          title: 'طلب خصم إداري بانتظار موافقتك',
          body: 'أنشأ HR طلب خصم إداري لـ (${targetEmployee.displayName}) قدره $fractionLabel - السبب: $reason',
          route: '/manager/requests',
          data: {'deductionId': ref.id},
        );
      }
    } else if (status == 'pending_hr') {
      final hrDocs = await _db
          .collection('users')
          .where('role', whereIn: ['hr_admin', 'hr_manager', 'super_admin'])
          .get();
      for (final doc in hrDocs.docs) {
        await _sendNotification(
          recipientId: doc.id,
          type: 'salary_deduction_pending',
          title: 'طلب خصم إداري بانتظار الاعتماد',
          body: 'أنشأ المدير ${creator.displayName} طلب خصم إداري لـ (${targetEmployee.displayName}) قدره $fractionLabel - السبب: $reason',
          route: '/manager/requests',
          data: {'deductionId': ref.id},
        );
      }
    } else if (status == 'approved') {
      await _sendNotification(
        recipientId: targetEmployee.uid,
        type: 'salary_deduction_approved',
        title: 'خصم راتب إداري',
        body: 'تم تسجيل خصم إداري قدره ($fractionLabel) بتاريخ $dateKey - السبب: $reason',
        route: '/employee/deductions',
        data: {'deductionId': ref.id},
      );
    }
  }

  Future<void> approveDeduction({
    required String deductionId,
    required UserModel reviewer,
  }) async {
    final ref = _db.collection('manual_deductions').doc(deductionId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('الطلب غير موجود');
    final deduction = ManualDeductionModel.fromFirestore(doc);

    await ref.update({
      'status': 'approved',
      'approvedBy': reviewer.uid,
      'approvedByName': reviewer.displayName,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'manual_deduction_approved',
      targetCollection: 'manual_deductions',
      targetId: deductionId,
      metadata: {'userId': deduction.userId},
    );

    // Send notification to employee
    await _sendNotification(
      recipientId: deduction.userId,
      type: 'salary_deduction_approved',
      title: 'تم اعتماد خصم راتب إداري',
      body: 'تم اعتماد خصم راتب إداري قدره (${deduction.fractionLabel}) بتاريخ ${deduction.dateKey} - السبب: ${deduction.reason}',
      route: '/employee/deductions',
      data: {'deductionId': deductionId},
    );
  }

  Future<void> rejectDeduction({
    required String deductionId,
    required UserModel reviewer,
    required String reason,
  }) async {
    final ref = _db.collection('manual_deductions').doc(deductionId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('الطلب غير موجود');
    final deduction = ManualDeductionModel.fromFirestore(doc);

    await ref.update({
      'status': 'rejected',
      'rejectedBy': reviewer.uid,
      'rejectedByName': reviewer.displayName,
      'rejectionReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'manual_deduction_rejected',
      targetCollection: 'manual_deductions',
      targetId: deductionId,
      metadata: {'userId': deduction.userId, 'reason': reason},
    );
  }

  Future<void> _sendNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    required String route,
    Map<String, dynamic>? data,
  }) async {
    final notifRef = _db
        .collection('notifications')
        .doc(recipientId)
        .collection('items')
        .doc();

    final payload = NotificationRoutePolicy.dataWithRoute(type, {
      ...?data,
      'route': route,
    });

    await notifRef.set({
      'notificationId': notifRef.id,
      'type': type,
      'title': title,
      'body': body,
      'data': payload,
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
