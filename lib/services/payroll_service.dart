import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../models/employee_role.dart';
import '../models/payroll_run_model.dart';
import '../models/user_model.dart';
import '../models/warning_reward_model.dart';
import 'audit_log_service.dart';

class PayrollService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<PayrollRunModel>> watchPayrollRuns(String monthKey) {
    return _db
        .collection('payrollRuns')
        .where('monthKey', isEqualTo: monthKey)
        .snapshots()
        .map(_runsFromSnapshot);
  }

  Stream<PayrollRunModel?> watchMyPayroll(String userId, String monthKey) {
    return _db
        .collection('payrollRuns')
        .doc('${userId}_$monthKey')
        .snapshots()
        .map((doc) => doc.exists ? PayrollRunModel.fromFirestore(doc) : null);
  }

  Future<PayrollRunModel> calculateForUser({
    required UserModel employee,
    required String monthKey,
    required String actorId,
  }) async {
    final nextMonthDateKey = _nextMonthDateKey(monthKey);
    final results = await Future.wait([
      _db
          .collection('attendance')
          .where('userId', isEqualTo: employee.uid)
          .where('date', isGreaterThanOrEqualTo: '$monthKey-01')
          .where('date', isLessThan: nextMonthDateKey)
          .get(),
      _db
          .collection('warningsRewards')
          .where('userId', isEqualTo: employee.uid)
          .where('monthKey', isEqualTo: monthKey)
          .get(),
    ]);

    final attendanceSnap = results[0];
    final rewardSnap = results[1];
    final attendance = attendanceSnap.docs
        .map((doc) => AttendanceModel.fromFirestore(doc))
        .toList();
    final rewards = rewardSnap.docs
        .map((doc) => WarningRewardModel.fromFirestore(doc))
        .toList();

    final approvedDeductions = attendance.where(
      (log) =>
          log.salaryDeductionApprovalStatus == 'approved' &&
          log.salaryDeductionAmount > 0,
    );
    final deductionTotal = approvedDeductions.fold<double>(
      0,
      (total, log) => total + log.salaryDeductionAmount,
    );

    final issuedBonusRecords = rewards.where((record) {
      final isBonusType =
          record.type == WarningRewardType.reward ||
          record.type == WarningRewardType.bonusRecommendation;
      final isIssued =
          record.status == WarningRewardStatus.issued ||
          record.status == WarningRewardStatus.acknowledged;
      return isBonusType && isIssued && record.amount > 0;
    });
    final bonusTotal = issuedBonusRecords.fold<double>(
      0,
      (total, record) => total + record.amount,
    );

    final netSalary = PayrollRunModel.calculateNetSalary(
      baseSalary: employee.baseMonthlySalary,
      deductions: deductionTotal,
      bonus: bonusTotal,
    );

    return PayrollRunModel(
      payrollId: '${employee.uid}_$monthKey',
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      managerId: employee.managerId ?? '',
      monthKey: monthKey,
      currency: employee.salaryCurrency,
      baseSalary: employee.baseMonthlySalary,
      attendanceDeductions: deductionTotal,
      rewardsBonus: bonusTotal,
      netSalary: netSalary,
      approvedDeductionCount: approvedDeductions.length,
      bonusRecordCount: issuedBonusRecords.length,
      status: PayrollStatus.draft,
      calculatedBy: actorId,
    );
  }

  Future<void> calculateAndCacheForUser({
    required UserModel employee,
    required String monthKey,
    required String actorId,
  }) async {
    final run = await calculateForUser(
      employee: employee,
      monthKey: monthKey,
      actorId: actorId,
    );
    await _db
        .collection('payrollRuns')
        .doc(run.payrollId)
        .set(run.toFirestore());
    await AuditLogService.instance.record(
      actorId: actorId,
      action: 'payroll_calculated',
      targetCollection: 'payrollRuns',
      targetId: run.payrollId,
      metadata: {
        'userId': employee.uid,
        'monthKey': monthKey,
        'netSalary': run.netSalary,
      },
    );
  }

  Future<int> calculateCompanyPayroll({
    required UserModel actor,
    required String monthKey,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isActive', isEqualTo: true);
    final usersSnap = await query.get();
    final users = usersSnap.docs.map(UserModel.fromFirestore).where((user) {
      return user.role != EmployeeRole.superAdmin;
    }).toList();

    for (final user in users) {
      await calculateAndCacheForUser(
        employee: user,
        monthKey: monthKey,
        actorId: actor.uid,
      );
    }
    return users.length;
  }

  Future<void> markReviewed(String payrollId, UserModel reviewer) async {
    await _db.collection('payrollRuns').doc(payrollId).update({
      'status': PayrollStatus.reviewed,
      'reviewedBy': reviewer.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'payroll_reviewed',
      targetCollection: 'payrollRuns',
      targetId: payrollId,
    );
  }

  Future<void> markLocked(String payrollId, UserModel locker) async {
    await _db.collection('payrollRuns').doc(payrollId).update({
      'status': PayrollStatus.locked,
    });
    await AuditLogService.instance.record(
      actorId: locker.uid,
      action: 'payroll_locked',
      targetCollection: 'payrollRuns',
      targetId: payrollId,
    );
  }

  List<PayrollRunModel> _runsFromSnapshot(QuerySnapshot snapshot) {
    final runs = snapshot.docs.map(PayrollRunModel.fromFirestore).toList();
    runs.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return runs;
  }

  String _nextMonthDateKey(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    return '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';
  }
}
