import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/attendance_model.dart';
import '../models/attendance_policy.dart';
import '../models/manual_deduction_model.dart';
import '../models/permission_model.dart';
import 'attendance_reconciliation_service.dart';
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
  final String? attendanceStatus;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? lateMinutes;
  final String? detailedExplanation;
  final String? policyRule;

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
    this.attendanceStatus,
    this.checkInTime,
    this.checkOutTime,
    this.lateMinutes,
    this.detailedExplanation,
    this.policyRule,
  });

  bool get hasCompleteDetails =>
      date.trim().isNotEmpty &&
      reasonLabel.trim().isNotEmpty &&
      amount != null &&
      (currency?.trim().isNotEmpty ?? false);

  List<String> get detailLines => [
    'المصدر: ${_orFallback(sourceLabel, 'غير محدد')}',
    'السبب: ${_orFallback(reasonLabel, 'غير مسجل في السجل التاريخي')}',
    if (detailedExplanation != null && detailedExplanation!.trim().isNotEmpty)
      'التفاصيل: $detailedExplanation',
    if (attendanceStatus != null) 'حالة الحضور: $attendanceStatus',
    if (lateMinutes != null && lateMinutes! > 0)
      'مقدار التأخير: $lateMinutes دقيقة',
    if (checkInTime != null)
      'وقت الحضور: ${DateFormat('hh:mm a', 'ar').format(checkInTime!)}',
    if (checkOutTime != null)
      'وقت الانصراف: ${DateFormat('hh:mm a', 'ar').format(checkOutTime!)}',
    if (policyRule != null && policyRule!.trim().isNotEmpty)
      'لائحة الخصم: $policyRule',
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

  String get deductionTitle => 'خصم $fractionLabel';

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
  final Set<String> _reconciledPermissionIds = <String>{};

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
                    ((item.isDeductible && item.salaryDeductionFraction > 0) ||
                        ((item.rejectionConsequence?['dayFraction'] as num?)
                                    ?.toDouble() ??
                                0) >
                            0),
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
            _reconcileApprovedLatePermissions(permissions);
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

  Future<List<EmployeeDeductionEntry>> getDeductionsForRange({
    required String userId,
    required String startDateKey,
    required String endDateKey,
    String? monthKey,
  }) async {
    final results = await Future.wait([
      _db
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDateKey)
          .where('date', isLessThanOrEqualTo: endDateKey)
          .get()
          .then((s) => s.docs.map(AttendanceModel.fromFirestore).toList())
          .catchError((_) => <AttendanceModel>[]),
      _db
          .collection('permissions')
          .where('userId', isEqualTo: userId)
          .get()
          .then((s) => s.docs.map(PermissionModel.fromFirestore).toList())
          .catchError((_) => <PermissionModel>[]),
      _db
          .collection('manual_deductions')
          .where('userId', isEqualTo: userId)
          .get()
          .then((s) => s.docs.map(ManualDeductionModel.fromFirestore).toList())
          .catchError((_) => <ManualDeductionModel>[]),
    ]);

    final attendance = results[0] as List<AttendanceModel>;
    final permissions = results[1] as List<PermissionModel>;
    final manualDeductions = results[2] as List<ManualDeductionModel>;

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
          .where((item) {
            final inRange =
                item.requestDate.compareTo(startDateKey) >= 0 &&
                item.requestDate.compareTo(endDateKey) <= 0;
            final isMonthMatch =
                monthKey == null || item.monthKey == monthKey;
            return (inRange || isMonthMatch) &&
                ((item.isDeductible && item.salaryDeductionFraction > 0) ||
                    ((item.rejectionConsequence?['dayFraction'] as num?)
                                ?.toDouble() ??
                            0) >
                        0);
          })
          .map(_fromPermission),
      ...manualDeductions
          .where((item) {
            final inRange =
                item.dateKey.compareTo(startDateKey) >= 0 &&
                item.dateKey.compareTo(endDateKey) <= 0;
            final isMonthMatch =
                monthKey == null || item.monthKey == monthKey;
            return inRange || isMonthMatch;
          })
          .map(_fromManualDeduction),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return entries;
  }


  void _reconcileApprovedLatePermissions(List<PermissionModel> permissions) {
    for (final permission in permissions) {
      if (permission.status != 'approved' ||
          permission.permissionType != 'late_arrival' ||
          !_reconciledPermissionIds.add(permission.permissionId)) {
        continue;
      }
      // Recovery for records approved while the app was closed or while a
      // previous reconciliation response was lost. The operation is
      // deterministic for the permission and attendance date.
      AttendanceReconciliationService()
          .reconcileApprovedPermission(permission)
          .catchError((_) {});
    }
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
    // Compute detailed explanation and policy rule
    String? explanation;
    String? rule;
    if (isAbsent) {
      explanation =
          'غياب كامل: لم يتم تسجيل أي بصمة حضور خلال ساعات العمل المقررة وبدون إجازة رسمية مسجلة.';
      rule =
          'المادة 12 من لائحة العمل: غياب يوم كامل بدون إذن مسبق = خصم يوم كامل (1.00) من الراتب.';
    } else if (item.lateMinutes > 0) {
      final timeStr = item.checkInTime != null
          ? DateFormat('hh:mm a', 'ar').format(item.checkInTime!)
          : '';
      if (item.lateMinutes <= 30) {
        explanation = timeStr.isNotEmpty
            ? 'تأخر في الحضور بمقدار ${item.lateMinutes} دقيقة (تم تسجيل الحضور الساعة $timeStr بعد موعد بداية العمل 09:00 ص).'
            : 'تأخر في الحضور بمقدار ${item.lateMinutes} دقيقة عن بداية وردية العمل.';
        rule =
            'لائحة الحضور: تأخير من 16 إلى 30 دقيقة (بعد فترة السماح 15 دقيقة) = خصم ربع يوم (0.25).';
      } else if (item.lateMinutes <= 60) {
        explanation = timeStr.isNotEmpty
            ? 'تأخر في الحضور بمقدار ${item.lateMinutes} دقيقة (تم تسجيل الحضور الساعة $timeStr بعد موعد بداية العمل 09:00 ص).'
            : 'تأخر في الحضور بمقدار ${item.lateMinutes} دقيقة عن بداية وردية العمل.';
        rule =
            'لائحة الحضور: تأخير من 31 إلى 60 دقيقة = خصم نصف يوم (0.50).';
      } else {
        explanation = timeStr.isNotEmpty
            ? 'تأخر كبير في الحضور بمقدار ${item.lateMinutes} دقيقة (تم تسجيل الحضور الساعة $timeStr).'
            : 'تأخر في الحضور بمقدار ${item.lateMinutes} دقيقة (أكثر من ساعة كاملة).';
        rule =
            'لائحة الحضور: تأخير أكثر من 60 دقيقة = خصم يوم كامل (1.00).';
      }
    } else if (item.checkOutTime == null &&
        (item.salaryDeductionCode.toLowerCase().contains('checkout') ||
            fraction == 0.25)) {
      explanation = 'عدم تسجيل بصمة الانصراف عند نهاية وردية العمل.';
      rule =
          'لائحة الحضور: عدم تسجيل بصمة الانصراف بدون عذر = خصم ربع يوم (0.25).';
    } else if (item.salaryDeductionLabel.trim().isNotEmpty) {
      explanation = item.salaryDeductionLabel.trim();
    }

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
      attendanceStatus:
          isAbsent
              ? 'لم يُسجّل حضور'
              : item.isLate
              ? 'حضور متأخر'
              : 'حضور وانصراف',
      checkInTime: item.checkInTime,
      checkOutTime: item.checkOutTime,
      lateMinutes: item.lateMinutes > 0 ? item.lateMinutes : null,
      detailedExplanation: explanation,
      policyRule: rule,
    );
  }

  EmployeeDeductionEntry _fromPermission(PermissionModel item) {
    final consequence = item.rejectionConsequence;
    if (consequence != null &&
        ((consequence['dayFraction'] as num?)?.toDouble() ?? 0) > 0) {
      final requestedHours =
          ((consequence['requestedMinutes'] as num?)?.toInt() ??
              item.durationMinutes) ~/
          60;
      final checkout = consequence['actualCheckoutAt'];
      final rejectionReason =
          (consequence['rejectionReason'] as String?)?.trim();
      return EmployeeDeductionEntry(
        id: '${item.permissionId}:early_leave_rejection',
        date: item.requestDate,
        sourceLabel: 'إذن مغادرة مبكرة مرفوض',
        reasonLabel:
            '${consequence['reasonLabel'] ?? 'استخدام مغادرة مبكرة بعد رفض الإذن'} · المطلوب $requestedHours ساعة${rejectionReason != null && rejectionReason.isNotEmpty ? ' · سبب الرفض: $rejectionReason' : ''}',
        dayFraction: (consequence['dayFraction'] as num?)?.toDouble() ?? 0,
        approvalStatus: _normalizedStatus(
          '${consequence['status'] ?? 'pending_hr'}',
        ),
        amount: (consequence['amount'] as num?)?.toDouble(),
        currency: consequence['currency'] as String? ?? item.salaryCurrency,
        checkOutTime:
            checkout is Timestamp
                ? checkout.toDate()
                : checkout is DateTime
                ? checkout
                : null,
        detailedExplanation:
            'مغادرة مقر العمل مبكراً بعد رفض طلب الإذن الرسمي أو دون موافقة الإدارة (مدة $requestedHours ساعة).',
        policyRule:
            'لائحة العمل: الانصراف المبكر دون إذن معتمد يستوجب خصم ساعات الغياب من الراتب.',
      );
    }
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
      detailedExplanation:
          item.reason.trim().isNotEmpty
              ? 'إذن خروج استقطاعي من الراتب: ${item.reason.trim()}'
              : 'إذن خروج استقطاعي من الراتب (${item.durationMinutes ~/ 60} ساعة).',
      policyRule:
          'استقطاع ساعات الإذن من الراتب وفقاً لرصيد الأذونات المستنفد.',
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
      detailedExplanation:
          'قرار خصم إداري صادر من إدارة الموارد البشرية: ${item.reason}',
      policyRule: 'عقوبة / جزاء إداري معتمد في ملف الموظف.',
    );
  }

  String _normalizedStatus(String value) {
    if (value == 'approved') return 'approved';
    if (value == 'rejected' || value == 'removed') return 'rejected';
    return 'pending_hr';
  }
}
