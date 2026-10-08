import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../features/request_approval_routing/data/custom_request_template_repository_impl.dart';
import '../features/request_approval_routing/domain/entities/custom_request_template.dart';
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
        .limit(25)
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
    final isExecutive = reviewer.canReviewExecutiveStage;
    if (isExecutive) {
      query = query.where(
        'status',
        whereIn: const ['pending_manager', 'pending_hr'],
      );
    } else if (reviewer.role == EmployeeRole.hrManager ||
        EmployeeRole.isHr(reviewer.role)) {
      query = query.where('status', isEqualTo: 'pending_hr');
    } else {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    }
    return query
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ResignationModel.fromFirestore).toList(),
        );
  }

  Future<void> submit({
    required UserModel employee,
    required String reason,
    required DateTime resignationDate,
    DateTime? lastWorkingDay,
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
      if (lastWorkingDay != null)
        'lastWorkingDay': Timestamp.fromDate(lastWorkingDay),
      'status': managerIds.isEmpty ? 'pending_hr' : 'pending_manager',
      'clearanceStatus': 'pending',
      'managerId': firstManagerId,
      'managerIds': managerIds,
      'managerNames': managerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': managerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'submittedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    try {
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
      if (lastWorkingDay != null) {
        await _createDynamicClearanceRequest(
          resignationId: ref.id,
          employee: employee,
          reason: cleanReason,
          resignationDate: resignationDate,
          lastWorkingDay: lastWorkingDay,
        );
      }
    } catch (e) {
      debugPrint('Resignation submission notification/clearance trigger failed: $e');
    }
  }

  Future<void> _createDynamicClearanceRequest({
    required String resignationId,
    required UserModel employee,
    required String reason,
    required DateTime resignationDate,
    required DateTime lastWorkingDay,
  }) async {
    try {
      final typeDoc = await _db
          .collection('customRequestTypes')
          .doc('core_clearance')
          .get();
      List<ApprovalChainStep> steps = [];
      if (typeDoc.exists && typeDoc.data() != null) {
        final data = typeDoc.data()!;
        final rawSteps = data['approvalSteps'] as List<dynamic>?;
        if (rawSteps != null && rawSteps.isNotEmpty) {
          steps = rawSteps
              .whereType<Map<String, dynamic>>()
              .map(ApprovalChainStep.fromMap)
              .toList();
          steps.sort((a, b) => a.order.compareTo(b.order));
        }
      }

      if (steps.isEmpty) {
        final defaultClearance = CustomRequestTemplateRepositoryImpl
            .defaultCoreRequestTypes
            .firstWhere(
              (t) => t.id == 'core_clearance',
              orElse: () =>
                  CustomRequestTemplateRepositoryImpl.defaultCoreRequestTypes.first,
            );
        steps = List.from(defaultClearance.approvalSteps);
        steps.sort((a, b) => a.order.compareTo(b.order));
      }

      final route = <Map<String, dynamic>>[];
      for (int i = 0; i < steps.length; i++) {
        final step = steps[i];
        final resolved = await _resolveApproverForStep(step, employee);
        route.add({
          'stageId': step.stepId.isNotEmpty ? step.stepId : 'step_${step.order}',
          'order': step.order,
          'approverType': step.approverType,
          'stageNameAr': step.labelAr,
          'approverId': resolved.id,
          'approverName': resolved.name,
          'department': step.department ?? '',
          'state': i == 0 ? 'pending' : 'waiting',
        });
      }

      final firstApproverId =
          route.isNotEmpty ? (route.first['approverId'] as String? ?? '') : '';
      final firstApproverName =
          route.isNotEmpty ? (route.first['approverName'] as String? ?? '') : '';

      final clearanceDocRef = _db.collection('customRequests').doc();
      final formattedLastDay =
          '${lastWorkingDay.year}-${lastWorkingDay.month.toString().padLeft(2, '0')}-${lastWorkingDay.day.toString().padLeft(2, '0')}';
      final clearanceData = {
        'requestId': clearanceDocRef.id,
        'resignationId': resignationId,
        'requesterId': employee.uid,
        'requesterName': employee.displayName,
        'employeeId': employee.employeeId,
        'department': employee.department,
        'typeId': 'core_clearance',
        'typeNameAr': 'إخلاء طرف',
        'title': 'طلب إخلاء طرف - ${employee.displayName}',
        'description':
            'طلب إخلاء طرف وتسليم العهد عند الاستقالة. آخر يوم عمل: $formattedLastDay. السبب: $reason',
        'status': 'pending',
        'approvalRoute': route,
        'currentApproverId': firstApproverId,
        'currentApproverName': firstApproverName,
        'currentApprovalIndex': 0,
        'lastWorkingDay': Timestamp.fromDate(lastWorkingDay),
        'resignationDate': Timestamp.fromDate(resignationDate),
        'approvalHistory': [
          {
            'action': 'submitted',
            'actorId': employee.uid,
            'actorName': employee.displayName,
            'at': DateTime.now().toUtc().toIso8601String(),
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await clearanceDocRef.set(clearanceData);

      await _db.collection('resignations').doc(resignationId).update({
        'clearanceRequestId': clearanceDocRef.id,
        'clearanceStatus': 'in_progress',
      });

      await _db.collection('clearances').doc(resignationId).set({
        'resignationId': resignationId,
        'clearanceRequestId': clearanceDocRef.id,
        'userId': employee.uid,
        'employeeId': employee.employeeId,
        'employeeName': employee.displayName,
        'department': employee.department,
        'lastWorkingDay': Timestamp.fromDate(lastWorkingDay),
        'resignationDate': Timestamp.fromDate(resignationDate),
        'reason': reason,
        'status': 'pending',
        'approvalRoute': route,
        'currentApproverId': firstApproverId,
        'currentApproverName': firstApproverName,
        'currentApprovalIndex': 0,
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (firstApproverId.isNotEmpty) {
        await RoleNotificationService.instance.createNotification(
          recipientId: firstApproverId,
          type: 'clearance_pending_approval',
          title: 'طلب إخلاء طرف بانتظار موافقتك',
          body:
              'طلب إخلاء طرف للموظف ${employee.displayName} (${route.first['stageNameAr']}).',
          data: {
            'clearanceId': clearanceDocRef.id,
            'resignationId': resignationId,
          },
        );
      }
    } catch (e) {
      debugPrint('Failed to create dynamic clearance request: $e');
    }
  }

  Future<({String id, String name})> _resolveApproverForStep(
    ApprovalChainStep step,
    UserModel employee,
  ) async {
    switch (step.approverType) {
      case 'direct_manager':
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
        if (managerIds.isNotEmpty) {
          return (
            id: managerIds.first,
            name: managerNames.isNotEmpty ? managerNames.first : 'المدير المباشر',
          );
        }
        break;

      case 'specific_user':
        if (step.specificUserId != null && step.specificUserId!.isNotEmpty) {
          return (
            id: step.specificUserId!,
            name: step.specificUserName ?? 'مسؤول معتمد',
          );
        }
        break;

      case 'it':
        try {
          final itSnap = await _db
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('isHiringItApprover', isEqualTo: true)
              .limit(1)
              .get();
          if (itSnap.docs.isNotEmpty) {
            final doc = itSnap.docs.first;
            final d = doc.data();
            return (
              id: doc.id,
              name: (d['displayName'] ?? d['name'] ?? 'مسؤول IT').toString(),
            );
          }
          final itFallback = await _db
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('department', isEqualTo: 'IT')
              .limit(1)
              .get();
          if (itFallback.docs.isNotEmpty) {
            final doc = itFallback.docs.first;
            final d = doc.data();
            return (
              id: doc.id,
              name: (d['displayName'] ?? d['name'] ?? 'مسؤول IT').toString(),
            );
          }
        } catch (_) {}
        break;

      case 'hr':
        try {
          final hrSnap = await _db
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('role', isEqualTo: 'hr_manager')
              .limit(1)
              .get();
          if (hrSnap.docs.isNotEmpty) {
            final doc = hrSnap.docs.first;
            final d = doc.data();
            return (
              id: doc.id,
              name: (d['displayName'] ?? d['name'] ?? 'مدير الموارد البشرية')
                  .toString(),
            );
          }
        } catch (_) {}
        break;

      case 'accounting':
        try {
          final accSnap = await _db
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('isAdvanceAccountsApprover', isEqualTo: true)
              .limit(1)
              .get();
          if (accSnap.docs.isNotEmpty) {
            final doc = accSnap.docs.first;
            final d = doc.data();
            return (
              id: doc.id,
              name: (d['displayName'] ?? d['name'] ?? 'مدير الحسابات والمالية')
                  .toString(),
            );
          }
        } catch (_) {}
        break;

      case 'ceo':
        try {
          final ceoSnap = await _db
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('role', isEqualTo: 'general_manager')
              .limit(1)
              .get();
          if (ceoSnap.docs.isNotEmpty) {
            final doc = ceoSnap.docs.first;
            final d = doc.data();
            return (
              id: doc.id,
              name: (d['displayName'] ?? d['name'] ?? 'الرئيس التنفيذي')
                  .toString(),
            );
          }
        } catch (_) {}
        break;

      case 'coo':
        try {
          final cooSnap = await _db
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('role', isEqualTo: 'coo')
              .limit(1)
              .get();
          if (cooSnap.docs.isNotEmpty) {
            final doc = cooSnap.docs.first;
            final d = doc.data();
            return (
              id: doc.id,
              name: (d['displayName'] ?? d['name'] ?? 'المدير التنفيذي للعمليات')
                  .toString(),
            );
          }
        } catch (_) {}
        break;

      case 'department_pool':
        final dept = step.department;
        if (dept != null && dept.isNotEmpty) {
          try {
            final deptSnap = await _db
                .collection('users')
                .where('isActive', isEqualTo: true)
                .where('role', isEqualTo: 'manager')
                .where('department', isEqualTo: dept)
                .limit(1)
                .get();
            if (deptSnap.docs.isNotEmpty) {
              final doc = deptSnap.docs.first;
              final d = doc.data();
              return (
                id: doc.id,
                name: (d['displayName'] ?? d['name'] ?? 'مدير القسم').toString(),
              );
            }
          } catch (_) {}
        }
        break;
    }

    return (id: '', name: step.labelAr);
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
        throw Exception('القرار النهائي للاستقالة متاح لـ HR فقط.');
      }
      await ref.update({
        'status': approve ? 'approved' : 'rejected',
        'reviewedBy': reviewer.uid,
        'reviewerName': reviewer.displayName,
        'reviewerComment': comment.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'clearanceStatus': approve ? 'archived_in_clearances' : 'rejected',
        'isRead': true,
      });

      if (approve) {
        try {
          await _db.collection('clearances').doc(resignationId).set({
            'resignationId': resignationId,
            'userId': request.userId,
            'employeeId': request.employeeId,
            'employeeName': request.employeeName,
            'department': request.department,
            'lastWorkingDay': request.lastWorkingDay != null
                ? Timestamp.fromDate(request.lastWorkingDay!)
                : null,
            'resignationDate': Timestamp.fromDate(request.resignationDate),
            'reason': request.reason,
            'status': 'cleared',
            'archivedAt': FieldValue.serverTimestamp(),
            'archivedBy': reviewer.uid,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Archiving resignation to clearances failed: $e');
        }
      }
    } else {
      final reviewerCode = reviewer.employeeId.trim().toUpperCase();
      final isMatchingManager =
          request.managerId == reviewer.uid ||
          (reviewerCode.isNotEmpty && request.managerId == reviewerCode) ||
          (snapshot.data()?['managerCodes'] as List<dynamic>?)?.contains(
                reviewerCode,
              ) ==
              true ||
          request.managerIds.contains(reviewer.uid) ||
          reviewer.isExecutiveLeader;
      if (request.status != 'pending_manager' || !isMatchingManager) {
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
      try {
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
      } catch (e) {
        debugPrint('Resignation review chain notification failed: $e');
      }
    }

    try {
      await RoleNotificationService.instance.createNotification(
        recipientId: request.userId,
        type: approve ? 'resignation_reviewed' : 'resignation_rejected',
        title: approve ? 'تم تحديث طلب الاستقالة' : 'تم رفض طلب الاستقالة',
        body: approve
            ? 'تمت الموافقة على المرحلة الحالية من طلب الاستقالة.'
            : 'سبب الرفض: ${comment.trim()}',
        data: {'resignationId': resignationId},
      );
    } catch (e) {
      debugPrint('Resignation employee update notification failed: $e');
    }
    try {
      await AuditLogService.instance.record(
        actorId: reviewer.uid,
        action: approve ? 'resignation_approved' : 'resignation_rejected',
        targetCollection: 'resignations',
        targetId: resignationId,
        metadata: {'userId': request.userId, 'comment': comment.trim()},
      );
    } catch (e) {
      debugPrint('Resignation audit record failed: $e');
    }
  }
}
