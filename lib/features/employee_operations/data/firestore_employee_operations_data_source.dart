import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/attendance_service.dart';
import '../../../models/attendance_model.dart';
import '../../../models/manual_deduction_model.dart';
import '../../../models/permission_model.dart';

/// Bounded source streams for the employee's selected payroll cycle only.
final class FirestoreEmployeeOperationsDataSource {
  FirestoreEmployeeOperationsDataSource({
    FirebaseFirestore? firestore,
    AttendanceService? attendanceService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _attendanceService = attendanceService ?? AttendanceService();

  final FirebaseFirestore _db;
  final AttendanceService _attendanceService;

  Stream<EmployeeDeductionSourceSnapshot> watchCycle({
    required String employeeUserId,
    required String effectiveCycleKey,
  }) {
    return Stream.multi((controller) {
      var attendance = <AttendanceModel>[];
      var permissions = <PermissionModel>[];
      var manual = <ManualDeductionModel>[];
      void emit() {
        if (!controller.isClosed) {
          controller.add(EmployeeDeductionSourceSnapshot(
            attendance: attendance,
            permissions: permissions,
            manualDeductions: manual,
          ));
        }
      }

      final attendanceSub = _attendanceService
          .watchMonthlyAttendance(employeeUserId, effectiveCycleKey)
          .listen((items) { attendance = items; emit(); }, onError: controller.addError);
      final permissionSub = _db
          .collection('permissions')
          .where('userId', isEqualTo: employeeUserId)
          .where('monthKey', isEqualTo: effectiveCycleKey)
          .limit(120)
          .snapshots()
          .listen((snapshot) {
            permissions = snapshot.docs.map(PermissionModel.fromFirestore).toList();
            emit();
          }, onError: controller.addError);
      final manualSub = _db
          .collection('manual_deductions')
          .where('userId', isEqualTo: employeeUserId)
          .where('monthKey', isEqualTo: effectiveCycleKey)
          .limit(120)
          .snapshots()
          .listen((snapshot) {
            manual = snapshot.docs.map(ManualDeductionModel.fromFirestore).toList();
            emit();
          }, onError: controller.addError);
      controller.onCancel = () async {
        await attendanceSub.cancel();
        await permissionSub.cancel();
        await manualSub.cancel();
      };
    });
  }
}

final class EmployeeDeductionSourceSnapshot {
  const EmployeeDeductionSourceSnapshot({
    required this.attendance,
    required this.permissions,
    required this.manualDeductions,
  });

  final List<AttendanceModel> attendance;
  final List<PermissionModel> permissions;
  final List<ManualDeductionModel> manualDeductions;
}
