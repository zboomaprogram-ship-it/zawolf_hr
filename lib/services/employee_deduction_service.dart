import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
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
    if (dayFraction >= 1) return 'يوم كامل';
    if (dayFraction >= 0.5) return 'نصف يوم';
    return 'ربع يوم';
  }

  String get approvalLabel {
    switch (approvalStatus) {
      case 'approved':
        return 'اعتمده HR';
      case 'rejected':
        return 'ألغاه HR';
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

      controller.onCancel = () async {
        await attendanceSub.cancel();
        await permissionSub.cancel();
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

  String _normalizedStatus(String value) {
    if (value == 'approved') return 'approved';
    if (value == 'rejected' || value == 'removed') return 'rejected';
    return 'pending_hr';
  }
}
