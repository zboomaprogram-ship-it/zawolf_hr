import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_policy.dart';
import '../models/leave_model.dart';
import '../models/permission_model.dart';
import '../models/user_model.dart';
import 'attendance_policy_service.dart';

class AttendanceReconciliationService {
  AttendanceReconciliationService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final AttendancePolicyService _policyService = AttendancePolicyService();

  Future<void> reconcileApprovedPermission(PermissionModel permission) async {
    final attendanceRef = _db
        .collection('attendance')
        .doc('${permission.userId}_${permission.requestDate}');
    final results = await Future.wait([
      attendanceRef.get(),
      _db.collection('users').doc(permission.userId).get(),
      _policyService.getPolicyConfig(),
    ]);
    final attendance = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final userDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final policy = results[2] as AttendancePolicyConfig;
    if (!attendance.exists || !userDoc.exists) return;

    final attendanceData = attendance.data()!;
    final employee = UserModel.fromFirestore(userDoc);
    final checkIn = (attendanceData['checkInTime'] as Timestamp?)?.toDate();
    final checkOut = (attendanceData['checkOutTime'] as Timestamp?)?.toDate();
    Map<String, dynamic>? patch;

    if (permission.permissionType == 'late_arrival' && checkIn != null) {
      final baseStart =
          employee.workSchedule.startTime ?? policy.defaultStartTime;
      final shiftedStart = AttendancePolicy.parseTimeOnDate(
        checkIn,
        baseStart,
      ).add(Duration(minutes: permission.durationMinutes));
      final deduction = policy.evaluateLateArrival(
        arrivalTime: checkIn,
        employeeStartTime:
            '${shiftedStart.hour.toString().padLeft(2, '0')}:${shiftedStart.minute.toString().padLeft(2, '0')}',
      );
      patch = _deductionPatch(
        deduction: deduction,
        employee: employee,
        policy: policy,
      );
    } else if (permission.permissionType == 'early_leave' && checkOut != null) {
      final baseEnd = AttendancePolicy.parseTimeOnDate(
        checkOut,
        employee.workSchedule.endTime ?? policy.defaultEndTime,
      );
      final allowedCheckout = baseEnd.subtract(
        Duration(minutes: permission.durationMinutes),
      );
      if (!checkOut.isBefore(allowedCheckout)) {
        patch = _noDeductionPatch();
      }
    }

    if (patch == null) return;
    await attendanceRef.update({
      ...patch,
      'reconciledPermissionId': permission.permissionId,
      'deductionReconciledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reconcileApprovedLeave(LeaveModel leave) async {
    final writes = <Future<void>>[];
    for (
      var day = DateTime(
        leave.startDate.year,
        leave.startDate.month,
        leave.startDate.day,
      );
      !day.isAfter(
        DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day),
      );
      day = day.add(const Duration(days: 1))
    ) {
      final dateKey =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final ref = _db.collection('attendance').doc('${leave.userId}_$dateKey');
      writes.add(_clearLeaveDay(ref, leave.leaveId));
    }
    await Future.wait(writes);
  }

  Future<void> _clearLeaveDay(
    DocumentReference<Map<String, dynamic>> ref,
    String leaveId,
  ) async {
    final doc = await ref.get();
    if (!doc.exists) return;
    final hasCheckIn = doc.data()?['checkInTime'] is Timestamp;
    await ref.update({
      ..._noDeductionPatch(),
      if (!hasCheckIn) 'status': 'on-leave',
      'reconciledLeaveId': leaveId,
      'deductionReconciledAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _deductionPatch({
    required AttendanceDeduction deduction,
    required UserModel employee,
    required AttendancePolicyConfig policy,
  }) {
    return {
      'status': deduction.status,
      'isLate': deduction.isLate,
      'lateMinutes': deduction.lateMinutes,
      'salaryDeductionFraction': deduction.dayFraction,
      'salaryDeductionAmount': policy.calculateSalaryDeductionAmount(
        monthlySalary: employee.baseMonthlySalary,
        dayFraction: deduction.dayFraction,
      ),
      'salaryCurrency': employee.salaryCurrency,
      'salaryDeductionCode': deduction.code,
      'salaryDeductionLabel': deduction.arabicLabel,
      'salaryDeductionApprovalStatus': deduction.dayFraction > 0
          ? 'pending_hr'
          : 'none',
    };
  }

  Map<String, dynamic> _noDeductionPatch() => const {
    'isLate': false,
    'lateMinutes': 0,
    'salaryDeductionFraction': 0.0,
    'salaryDeductionAmount': 0.0,
    'salaryDeductionCode': 'none',
    'salaryDeductionLabel': 'لا يوجد خصم',
    'salaryDeductionApprovalStatus': 'none',
  };
}
