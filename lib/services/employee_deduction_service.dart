import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../models/manual_deduction_model.dart';
import '../models/permission_model.dart';
import 'attendance_service.dart';

class EmployeeDeductionEntry {
  final String id;
  final String date;
  final String sourceLabel;
  final String reasonLabel;
  final double dayFraction;
  final String approvalStatus;

  const EmployeeDeductionEntry({
    required this.id,
    required this.date,
    required this.sourceLabel,
    required this.reasonLabel,
    required this.dayFraction,
    required this.approvalStatus,
  });

  String get fractionLabel {
    if (dayFraction >= 3.0) return '3 أيام';
    if (dayFraction >= 2.0) return 'يومان';
    if (dayFraction >= 1.0) return 'يوم كامل';
    if (dayFraction >= 0.5) return 'نصف يوم';
    return 'ربع يوم';
  }

  String get approvalLabel {
    switch (approvalStatus) {
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'ملغى';
      case 'pending_manager':
        return 'بانتظار موافقة المدير';
      default:
        return 'بانتظار مراجعة HR';
    }
  }
}

class EmployeeDeductionService {
  EmployeeDeductionService({
    FirebaseFirestore? firestore,
    AttendanceService? attendanceService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _attendanceService = attendanceService ?? AttendanceService();

  final FirebaseFirestore _db;
  final AttendanceService _attendanceService;

  Stream<List<EmployeeDeductionEntry>> watchForCycle({
    required String userId,
    required String monthKey,
  }) {
    return Stream.multi((controller) {
      var attendance = <AttendanceModel>[];
      var permissions = <PermissionModel>[];
      var manualDeductions = <ManualDeductionModel>[];

      void emit() {
        final entries = <EmployeeDeductionEntry>[
          ...attendance
              .where((item) => item.salaryDeductionFraction > 0)
              .map(_fromAttendance),
          ...permissions
              .where(
                (item) =>
                    item.monthKey == monthKey &&
                    item.isDeductible &&
                    item.salaryDeductionFraction > 0,
              )
              .map(_fromPermission),
          ...manualDeductions
              .where((item) => item.monthKey == monthKey)
              .map(_fromManualDeduction),
        ]..sort((a, b) => b.date.compareTo(a.date));
        if (!controller.isClosed) controller.add(entries);
      }

      final attendanceSub = _attendanceService
          .watchMonthlyAttendance(userId, monthKey)
          .listen((items) {
            attendance = items;
            emit();
          }, onError: controller.addError);

      final permissionSub = _db
          .collection('permissions')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
            permissions = snapshot.docs
                .map(PermissionModel.fromFirestore)
                .toList();
            emit();
          }, onError: controller.addError);

      final manualSub = _db
          .collection('manual_deductions')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
            manualDeductions = snapshot.docs
                .map(ManualDeductionModel.fromFirestore)
                .toList();
            emit();
          }, onError: controller.addError);

      controller.onCancel = () async {
        await attendanceSub.cancel();
        await permissionSub.cancel();
        await manualSub.cancel();
      };
    });
  }

  EmployeeDeductionEntry _fromAttendance(AttendanceModel item) {
    return EmployeeDeductionEntry(
      id: item.attendanceId,
      date: item.date,
      sourceLabel: 'الحضور والانصراف',
      reasonLabel: item.salaryDeductionLabel,
      dayFraction: item.salaryDeductionFraction,
      approvalStatus: _normalizedStatus(item.salaryDeductionApprovalStatus),
    );
  }

  EmployeeDeductionEntry _fromPermission(PermissionModel item) {
    final status = item.status == 'rejected' || item.status == 'cancelled'
        ? 'rejected'
        : _normalizedStatus(item.salaryDeductionApprovalStatus);
    return EmployeeDeductionEntry(
      id: item.permissionId,
      date: item.requestDate,
      sourceLabel: 'إذن استقطاعي',
      reasonLabel: item.salaryDeductionLabel,
      dayFraction: item.salaryDeductionFraction,
      approvalStatus: status,
    );
  }

  EmployeeDeductionEntry _fromManualDeduction(ManualDeductionModel item) {
    return EmployeeDeductionEntry(
      id: item.id,
      date: item.dateKey,
      sourceLabel: 'خصم إداري',
      reasonLabel: item.reason,
      dayFraction: item.dayFraction,
      approvalStatus: item.status,
    );
  }

  String _normalizedStatus(String value) {
    if (value == 'approved') return 'approved';
    if (value == 'rejected' || value == 'removed') return 'rejected';
    return 'pending_hr';
  }
}
