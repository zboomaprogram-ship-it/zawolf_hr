import 'package:intl/intl.dart' hide TextDirection;
import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/permission_model.dart';
import '../models/performance_model.dart';
import '../models/payroll_run_model.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';

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

  Future<String> exportPayrollToSheet(
    String exportName,
    List<PayrollRunModel> runs,
  ) async {
    final rows = <List<Object?>>[
      [
        'الكود التعريفي (ID)',
        'اسم الموظف (Employee)',
        'القسم (Department)',
        'الشهر (Month)',
        'الراتب الأساسي',
        'خصومات الحضور',
        'السلف',
        'المكافآت',
        'صافي الراتب',
        'العملة',
        'الحالة',
      ],
      ...runs.map(
        (run) => [
          run.employeeId,
          run.employeeName,
          run.department,
          run.monthKey,
          run.baseSalary.toStringAsFixed(2),
          run.attendanceDeductions.toStringAsFixed(2),
          run.advances.toStringAsFixed(2),
          run.rewardsBonus.toStringAsFixed(2),
          run.netSalary.toStringAsFixed(2),
          run.currency,
          PayrollStatus.arabicLabel(run.status),
        ],
      ),
    ];

    return _toCsv(rows);
  }

  Future<String> exportEmployeesToSheet(
    String exportName,
    List<UserModel> employees,
  ) async {
    final rows = <List<Object?>>[
      [
        'الكود التعريفي (Employee ID)',
        'الاسم (Name)',
        'البريد الإلكتروني (Email)',
        'الدور (Role)',
        'المسمى الوظيفي (Position)',
        'القسم (Department)',
        'الفرع (Location)',
        'المدير المباشر (Manager)',
        'الراتب الأساسي (Base Salary)',
        'العملة (Currency)',
        'رصيد الإجازات السنوية',
        'رصيد الإجازات المرضية',
        'رصيد الإجازات العارضة',
        'رصيد أيام العطلات',
        'الأذونات المستخدمة هذا الشهر',
        'الحالة (Status)',
        'تاريخ الانضمام',
        'جهاز الحضور',
      ],
      ...employees.map(
        (emp) => [
          emp.employeeId,
          emp.displayName,
          emp.email,
          EmployeeRole.arabicLabel(emp.role),
          emp.position,
          emp.department,
          emp.locationName,
          emp.managerName ?? '-',
          emp.baseMonthlySalary.toStringAsFixed(2),
          emp.salaryCurrency,
          emp.leaveBalance.annual,
          emp.leaveBalance.sick,
          emp.leaveBalance.casual,
          emp.leaveBalance.daysOff,
          emp.permissionBalance.usedThisMonth,
          emp.isActive ? 'نشط' : 'معطل',
          emp.joinDate != null
              ? DateFormat('yyyy-MM-dd').format(emp.joinDate!)
              : '-',
          emp.registeredAttendanceDeviceLabel ?? 'لم يتم الربط',
        ],
      ),
    ];

    return _toCsv(rows);
  }

  String generateImportTemplate() {
    final headers = [
      'email',
      'displayName',
      'employeeId',
      'role',
      'department',
      'position',
      'locationId',
      'locationName',
      'baseMonthlySalary',
      'salaryCurrency',
      'managerId',
      'managerName',
      'managerEmail',
      'managerCodes',
    ];
    final exampleRows = [
      [
        'marketing.manager@company.com',
        'مدير التسويق',
        'MKT-MGR-001',
        'manager',
        'التسويق',
        'Marketing Manager',
        '',
        'القاهرة',
        '12000',
        'EGP',
        '',
        '',
        '',
        '',
      ],
      [
        'marketing.employee1@company.com',
        'موظف تسويق 1',
        'MKT-EMP-001',
        'employee',
        'التسويق',
        'Marketing Specialist',
        '',
        'القاهرة',
        '6000',
        'EGP',
        '',
        '',
        'marketing.manager@company.com',
        'MKT-MGR-001',
      ],
    ];
    return _toCsv([headers, ...exampleRows]);
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
      case 'day_off':
        return 'يوم إجازة';
      case 'unpaid':
        return 'إجازة بدون راتب';
      case 'exam':
        return 'إجازة امتحان';
      default:
        return type;
    }
  }
}
