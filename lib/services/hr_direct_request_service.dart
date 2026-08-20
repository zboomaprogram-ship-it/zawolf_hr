import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/leave_model.dart';
import '../models/leave_type_policy.dart';
import '../models/permission_model.dart';
import '../models/permission_type_policy.dart';
import '../models/user_model.dart';
import '../utils/payroll_cycle.dart';
import 'attendance_policy_service.dart';
import 'attendance_reconciliation_service.dart';
import 'attendance_gateway_service.dart';
import 'role_notification_service.dart';

/// Creates HR-granted leave and permission records with no approval chain.
class HrDirectRequestService {
  HrDirectRequestService({
    FirebaseFirestore? firestore,
    AttendanceGatewayService? attendanceGateway,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _attendanceGateway = attendanceGateway ?? AttendanceGatewayService();

  final FirebaseFirestore _db;
  final AttendanceGatewayService _attendanceGateway;
  final AttendanceReconciliationService _reconciliation =
      AttendanceReconciliationService();

  Future<Map<String, dynamic>> _checkoutDecisionSnapshot(
    String permissionType,
  ) async {
    if (permissionType != PermissionTypePolicy.earlyLeave) {
      return const <String, dynamic>{};
    }
    try {
      final result = await _attendanceGateway.checkoutPolicy();
      final policy = result['policy'];
      final map = policy is Map ? policy : const <String, dynamic>{};
      return {
        'checkoutPolicyEnabled': map['enabled'] == true,
        'checkoutPolicyRevision': map['revision'] is int
            ? map['revision'] as int
            : 0,
        'checkoutPolicyEvaluatedAt': FieldValue.serverTimestamp(),
        'checkoutPolicyDecisionPoint': 'hr_direct_permission_approval',
      };
    } catch (_) {
      return {
        'checkoutPolicyEnabled': false,
        'checkoutPolicyRevision': 0,
        'checkoutPolicyEvaluatedAt': FieldValue.serverTimestamp(),
        'checkoutPolicyDecisionPoint':
            'hr_direct_permission_approval_unavailable',
      };
    }
  }

  Future<void> grantLeave({
    required UserModel employee,
    required UserModel hr,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    if (!LeaveTypePolicy.supportedTypes.contains(leaveType)) {
      throw Exception('نوع الإجازة غير صالح.');
    }
    if (endDate.isBefore(startDate)) {
      throw Exception('تاريخ النهاية يجب أن يكون بعد تاريخ البداية.');
    }
    if (reason.trim().isEmpty) throw Exception('سبب الإضافة مطلوب.');
    final days = endDate.difference(startDate).inDays + 1;
    final balanceKeys = LeaveTypePolicy.balanceKeys(leaveType);
    final ref = _db.collection('leaves').doc();
    final leave = LeaveModel(
      leaveId: ref.id,
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      locationId: employee.locationId,
      managerId: '',
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: days,
      reason: reason.trim(),
      workHandoverTo: 'أضيفت مباشرة بواسطة HR',
      status: 'approved',
      submittedAt: DateTime.now(),
      reviewedAt: DateTime.now(),
      reviewedBy: hr.uid,
      reviewerName: hr.displayName,
    );
    await _db.runTransaction((transaction) async {
      if (balanceKeys.isNotEmpty) {
        final userRef = _db.collection('users').doc(employee.uid);
        final latest = await transaction.get(userRef);
        if (!latest.exists) throw Exception('حساب الموظف غير موجود.');
        final balance = UserModel.fromFirestore(latest).leaveBalance;
        if (balance.daysOff < days ||
            (leaveType == LeaveTypePolicy.casual && balance.casual < days)) {
          throw Exception('رصيد الإجازات لا يكفي لهذه المدة.');
        }
        transaction.update(userRef, {
          for (final key in balanceKeys)
            'leaveBalance.$key': FieldValue.increment(-days),
        });
      }
      transaction.set(ref, {
        ...leave.toFirestore(),
        'managerIds': <String>[],
        'managerNames': <String>[],
        'managerApprovalIndex': 0,
        'managerApprovalTotal': 0,
        'managerApprovalTrail': <Map<String, dynamic>>[],
        'deductsLeaveBalance': balanceKeys.isNotEmpty,
        if (LeaveTypePolicy.balanceKey(leaveType) != null)
          'leaveBalanceKey': LeaveTypePolicy.balanceKey(leaveType),
        if (balanceKeys.isNotEmpty) 'leaveBalanceKeys': balanceKeys,
        'requiresFullDaySalaryDeduction':
            LeaveTypePolicy.requiresFullDaySalaryDeduction(leaveType),
        'requiresCeoApproval': false,
        'requiresHrApproval': false,
        'directHrGrant': true,
        'grantedBy': hr.uid,
        'grantedByName': hr.displayName,
        'approvalHistory': [
          {
            'stage': 'hr_direct',
            'status': 'approved',
            'actorId': hr.uid,
            'actorName': hr.displayName,
            'timestamp': Timestamp.now(),
          },
        ],
      });
    });
    await _reconciliation.reconcileApprovedLeave(leave);
    await RoleNotificationService.instance.createNotification(
      recipientId: employee.uid,
      type: 'leave_approved',
      title: 'أضاف HR إجازة معتمدة',
      body:
          '${LeaveTypePolicy.arabicLabel(leaveType)} من ${DateFormat('yyyy/MM/dd').format(startDate)} إلى ${DateFormat('yyyy/MM/dd').format(endDate)}.',
      data: {'leaveId': ref.id},
    );
  }

  Future<void> grantPermission({
    required UserModel employee,
    required UserModel hr,
    required String permissionType,
    required DateTime date,
    required String expectedTime,
    required int durationMinutes,
    required String reason,
    required bool isDeductible,
  }) async {
    if (![
      PermissionTypePolicy.earlyLeave,
      PermissionTypePolicy.lateArrival,
      PermissionTypePolicy.midShiftExit,
    ].contains(permissionType)) {
      throw Exception('نوع الإذن غير صالح.');
    }
    if (durationMinutes < 60 || durationMinutes > 240) {
      throw Exception('مدة الإذن يجب أن تكون من ساعة إلى 4 ساعات.');
    }
    if (reason.trim().isEmpty) throw Exception('سبب الإضافة مطلوب.');
    final policy = await AttendancePolicyService().getPolicyConfig();
    final fraction = isDeductible
        ? PermissionTypePolicy.deductibleDayFraction(durationMinutes)
        : 0.0;
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final ref = _db.collection('permissions').doc();
    final permission = PermissionModel(
      permissionId: ref.id,
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      locationId: employee.locationId,
      managerId: '',
      permissionType: permissionType,
      requestDate: dateKey,
      expectedTime: expectedTime,
      durationMinutes: durationMinutes,
      reason: reason.trim(),
      status: 'approved',
      isExceedingQuota: isDeductible,
      isDeductible: isDeductible,
      isSubmittedAfterWorkStart: false,
      salaryDeductionFraction: fraction,
      salaryDeductionAmount: policy.calculateSalaryDeductionAmount(
        monthlySalary: employee.baseMonthlySalary,
        dayFraction: fraction,
      ),
      salaryCurrency: employee.salaryCurrency,
      salaryDeductionCode: isDeductible
          ? PermissionTypePolicy.deductionCode(durationMinutes)
          : 'none',
      salaryDeductionLabel: isDeductible
          ? PermissionTypePolicy.deductionLabel(durationMinutes)
          : 'لا يوجد خصم',
      salaryDeductionApprovalStatus: isDeductible ? 'approved' : 'none',
      monthKey: PayrollCycle.keyFor(date),
      submittedAt: DateTime.now(),
      reviewedAt: DateTime.now(),
      reviewedBy: hr.uid,
      reviewerName: hr.displayName,
    );
    final timeParts = expectedTime.split(':').map(int.parse).toList();
    final checkoutDecisionSnapshot = await _checkoutDecisionSnapshot(
      permissionType,
    );
    await ref.set({
      ...permission.toFirestore(),
      ...checkoutDecisionSnapshot,
      'requestDateTimestamp': Timestamp.fromDate(date),
      'expectedTimestamp': Timestamp.fromDate(
        DateTime(date.year, date.month, date.day, timeParts[0], timeParts[1]),
      ),
      'managerIds': <String>[],
      'managerNames': <String>[],
      'managerApprovalIndex': 0,
      'managerApprovalTotal': 0,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'requiresHrApproval': false,
      'directHrGrant': true,
      'grantedBy': hr.uid,
      'grantedByName': hr.displayName,
      'approvalHistory': [
        {
          'stage': 'hr_direct',
          'status': 'approved',
          'actorId': hr.uid,
          'actorName': hr.displayName,
          'timestamp': Timestamp.now(),
        },
      ],
    });
    await _reconciliation.reconcileApprovedPermission(permission);
    await RoleNotificationService.instance.createNotification(
      recipientId: employee.uid,
      type: 'permission_approved',
      title: 'أضاف HR إذناً معتمداً',
      body:
          '${PermissionTypePolicy.arabicLabel(permissionType)} يوم ${DateFormat('yyyy/MM/dd').format(date)}.',
      data: {'permissionId': ref.id},
    );
  }
}
