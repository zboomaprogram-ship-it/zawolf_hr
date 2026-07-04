import 'package:intl/intl.dart' hide TextDirection;
import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/permission_model.dart';
import '../models/performance_model.dart';

class SheetsExportService {
  Future<String> exportAttendanceToSheet(
    String exportName,
    List<AttendanceModel> logs,
  ) async {
    final rows = <List<Object?>>[
      [
        'الكود التعريفي للموظف (Employee ID)',
        'الاسم (Name)',
        'التاريخ (Date)',
        'الفرع (Branch)',
        'توقيت الحضور (Check-In)',
        'توقيت الانصراف (Check-Out)',
        'دقائق التأخير (Late Minutes)',
        'الحالة (Status)',
        'اعتماد خصم الراتب',
        'قيمة الخصم',
        'النطاق الجغرافي (Geofence Verified)',
      ],
      ...logs.map(
        (log) => [
          log.employeeId,
          log.employeeName,
          log.date,
          log.locationName,
          log.checkInTime != null
              ? DateFormat('hh:mm a').format(log.checkInTime!)
              : '-',
          log.checkOutTime != null
              ? DateFormat('hh:mm a').format(log.checkOutTime!)
              : '-',
          log.lateMinutes,
          _translateStatus(log.status),
          _translateDeductionApproval(log.salaryDeductionApprovalStatus),
          '${log.salaryDeductionAmount.toStringAsFixed(2)} ${log.salaryCurrency}',
          log.isWithinGeofence ? 'نعم (داخل)' : 'لا (خارج)',
        ],
      ),
    ];

    return _toCsv(rows);
  }

  Future<String> exportLeavesToSheet(
    String exportName,
    List<LeaveModel> leaves,
  ) async {
    final rows = <List<Object?>>[
      [
        'الكود التعريفي (ID)',
        'اسم الموظف (Employee)',
        'القسم (Department)',
        'نوع الإجازة (Leave Type)',
        'تاريخ البداية (Start Date)',
        'تاريخ النهاية (End Date)',
        'عدد الأيام (Days Count)',
        'الحالة (Status)',
        'السبب (Reason)',
        'المراجع (Reviewed By)',
      ],
      ...leaves.map(
        (leave) => [
          leave.employeeId,
          leave.employeeName,
          leave.department,
          _translateLeaveType(leave.leaveType),
          DateFormat('yyyy-MM-dd').format(leave.startDate),
          DateFormat('yyyy-MM-dd').format(leave.endDate),
          leave.numberOfDays,
          _translateStatus(leave.status),
          leave.reason ?? '-',
          leave.reviewedBy ?? '-',
        ],
      ),
    ];

    return _toCsv(rows);
  }

  Future<String> exportPermissionsToSheet(
    String exportName,
    List<PermissionModel> permissions,
  ) async {
    final rows = <List<Object?>>[
      [
        'الكود التعريفي (ID)',
        'اسم الموظف (Employee)',
        'القسم (Department)',
        'نوع الإذن (Type)',
        'التاريخ المطلوب (Date)',
        'الوقت المتوقع (Time)',
        'المدة بالدقائق (Duration Mins)',
        'الحالة (Status)',
        'مرحلة الموافقة',
        'السبب (Reason)',
        'تجاوز الحصة (Exceeded Quota)',
        'خصم الراتب',
      ],
      ...permissions.map(
        (permission) => [
          permission.employeeId,
          permission.employeeName,
          permission.department,
          permission.permissionType == 'early_leave'
              ? 'مغادرة مبكرة'
              : 'تأخير حضور',
          permission.requestDate,
          permission.expectedTime,
          permission.durationMinutes,
          _translateStatus(permission.status),
          _permissionStage(permission.status),
          permission.reason,
          permission.isExceedingQuota ? 'نعم (تجاوز)' : 'لا',
          permission.salaryDeductionFraction > 0
              ? '${permission.salaryDeductionLabel} - ${permission.salaryDeductionAmount.toStringAsFixed(2)} ${permission.salaryCurrency}'
              : 'لا يوجد',
        ],
      ),
    ];

    return _toCsv(rows);
  }

  Future<String> exportPerformanceToSheet(
    String exportName,
    List<PerformanceModel> evaluations,
  ) async {
    final rows = <List<Object?>>[
      [
        'الكود التعريفي (ID)',
        'اسم الموظف (Employee)',
        'الشهر (Month)',
        'الحضور (Attendance)',
        'الانضباط (Punctuality)',
        'الجودة (Quality)',
        'التعاون (Teamwork)',
        'الالتزام (Commitment)',
        'التقييم الكلي (Overall)',
        'التقدير (Grade)',
        'التعليقات (Comments)',
      ],
      ...evaluations.map(
        (evaluation) => [
          evaluation.employeeId,
          evaluation.employeeName,
          evaluation.monthKey,
          evaluation.attendanceScore,
          evaluation.punctualityScore,
          evaluation.qualityScore,
          evaluation.teamworkScore,
          evaluation.commitmentScore,
          evaluation.overallScore,
          evaluation.grade,
          evaluation.comments ?? '-',
        ],
      ),
    ];

    return _toCsv(rows);
  }

  String _toCsv(List<List<Object?>> rows) {
    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
  }

  String _escapeCsv(Object? value) {
    final text = (value ?? '').toString();
    final escaped = text.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'late':
        return 'متأخر';
      case 'absent':
        return 'غائب';
      case 'on-leave':
        return 'إجازة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
        return 'معلق';
      case 'pending_hr':
        return 'بانتظار HR';
      case 'pending_manager':
        return 'بانتظار المدير';
      case 'invalid_late':
        return 'مرفوض تلقائياً (تأخير غير مقبول)';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String _permissionStage(String status) {
    switch (status) {
      case 'pending_hr':
        return 'مراجعة HR';
      case 'pending_manager':
        return 'موافقة المدير النهائية';
      case 'approved':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return '-';
    }
  }

  String _translateDeductionApproval(String status) {
    switch (status) {
      case 'pending_hr':
        return 'بانتظار HR';
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض/متنازل عنه';
      case 'none':
      default:
        return 'لا يوجد';
    }
  }

  String _translateLeaveType(String type) {
    switch (type) {
      case 'annual':
        return 'إجازة سنوية';
      case 'sick':
        return 'إجازة مرضية';
      case 'casual':
        return 'إجازة عارضة';
      default:
        return type;
    }
  }
}
