import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../models/attendance_policy.dart';
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
  final double? amount;
  final String? currency;
  final DateTime? approvedAt;
  final String? approvedByName;

  const EmployeeDeductionEntry({
    required this.id,
    required this.date,
    required this.sourceLabel,
    required this.reasonLabel,
    required this.dayFraction,
    required this.approvalStatus,
    this.amount,
    this.currency,
    this.approvedAt,
    this.approvedByName,
  });

  bool get hasCompleteDetails =>
      date.trim().isNotEmpty &&
      reasonLabel.trim().isNotEmpty &&
      amount != null &&
      (currency?.trim().isNotEmpty ?? false);

  List<String> get detailLines => [
    'المصدر: ${_orFallback(sourceLabel, 'غير محدد')}',
    'السبب: ${_orFallback(reasonLabel, 'غير مسجل في السجل التاريخي')}',
    'تاريخ الاستحقاق: ${_orFallback(date, 'غير متاح')}',
    'الخصم: $fractionLabel',
    'القيمة: ${_amountLabel()}',
    'حالة المراجعة: $approvalLabel',
  ];

  static String _orFallback(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  String _amountLabel() {
    if (amount == null) return 'غير مسجلة';
    final value = amount!;
    final formatted =
        value == value.roundToDouble()
            ? value.toStringAsFixed(2)
            : value.toStringAsFixed(2);
    final valueCurrency = currency?.trim();
    return valueCurrency == null || valueCurrency.isEmpty
        ? '$formatted (العملة غير مسجلة)'
        : '$formatted $valueCurrency';
  }

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
              .where(
                (item) =>
                    item.salaryDeductionFraction > 0 ||
                    item.status == 'absent' ||
                    item.salaryDeductionCode == 'ABSENCE' ||
                    item.salaryDeductionCode == 'full_day',
              )
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
            permissions =
                snapshot.docs.map(PermissionModel.fromFirestore).toList();
            emit();
          }, onError: controller.addError);

      final manualSub = _db
          .collection('manual_deductions')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
            manualDeductions =
                snapshot.docs.map(ManualDeductionModel.fromFirestore).toList();
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
    final isApproved = item.salaryDeductionApprovalStatus == 'approved';
    final isAbsent =
        item.status == 'absent' ||
        item.salaryDeductionCode == 'ABSENCE' ||
        item.salaryDeductionCode == 'full_day';
    final fraction =
        item.salaryDeductionFraction > 0
            ? item.salaryDeductionFraction
            : (isAbsent ? 1.0 : 0.0);
    final fallbackReason =
        isAbsent ? 'غياب كامل: لم يُسجّل حضور خلال وردية العمل' : 'خصم تأخير';
    // Legacy absence rows use the stable ABSENCE code.  The generic policy
    // label used to turn that into only "خصم يوم كامل", hiding the actual
    // reason from the employee. Preserve an authored label when available and
    // otherwise explain the missing attendance explicitly.
    final reason =
        isAbsent
            ? (item.salaryDeductionLabel.trim().isNotEmpty &&
                    item.salaryDeductionLabel.trim() != 'خصم غياب (يوم كامل)'
                ? item.salaryDeductionLabel.trim()
                : fallbackReason)
            : AttendancePolicy.arabicDeductionLabel(
              item.salaryDeductionCode,
              fallback:
                  item.salaryDeductionLabel.isNotEmpty
                      ? item.salaryDeductionLabel
                      : fallbackReason,
            );
    return EmployeeDeductionEntry(
      id: item.attendanceId,
      date: item.date,
      sourceLabel: isAbsent ? 'سجل الغياب' : 'الحضور والانصراف',
      reasonLabel: reason,
      dayFraction: fraction,
      approvalStatus: _normalizedStatus(item.salaryDeductionApprovalStatus),
      amount: item.salaryDeductionAmount,
      currency: item.salaryCurrency,
      approvedAt:
          item.salaryDeductionReviewedAt ??
          (isApproved ? item.checkInTime : null),
      approvedByName: item.salaryDeductionReviewedBy,
    );
  }

  EmployeeDeductionEntry _fromPermission(PermissionModel item) {
    final status =
        item.status == 'rejected' || item.status == 'cancelled'
            ? 'rejected'
            : _normalizedStatus(item.salaryDeductionApprovalStatus);
    return EmployeeDeductionEntry(
      id: item.permissionId,
      date: item.requestDate,
      sourceLabel: 'إذن استقطاعي',
      reasonLabel: item.salaryDeductionLabel,
      dayFraction: item.salaryDeductionFraction,
      approvalStatus: status,
      amount: item.salaryDeductionAmount,
      currency: item.salaryCurrency,
      approvedAt: item.reviewedAt ?? item.hrReviewedAt,
      approvedByName: item.reviewerName ?? item.reviewedBy,
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
      // Manual deductions are recorded as a payroll fraction. They have no
      // monetary amount unless payroll has written one, so do not invent it.
      amount: null,
      currency: null,
      approvedAt: item.approvedAt ?? item.createdAt,
      approvedByName: item.approvedByName ?? item.createdByName,
    );
  }

  String _normalizedStatus(String value) {
    if (value == 'approved') return 'approved';
    if (value == 'rejected' || value == 'removed') return 'rejected';
    return 'pending_hr';
  }
}
