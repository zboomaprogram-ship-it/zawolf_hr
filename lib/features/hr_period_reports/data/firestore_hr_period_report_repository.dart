import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../services/dashboard_attendance_summary_service.dart';
import '../../../services/google_workspace_service.dart';
import '../domain/hr_period_report.dart';
import '../domain/hr_period_report_repository.dart';

/// Read adapter for the in-app report. It delegates attendance classification
/// to the existing attendance authority so leave/permission precedence and
/// work-schedule rules stay identical to the dashboard and payroll views.
final class FirestoreHrPeriodReportRepository
    implements HrPeriodReportRepository {
  FirestoreHrPeriodReportRepository({
    DashboardAttendanceSummaryService? attendance,
    FirebaseFirestore? firestore,
  }) : _attendance = attendance ?? DashboardAttendanceSummaryService(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final DashboardAttendanceSummaryService _attendance;
  final FirebaseFirestore _firestore;

  @override
  Future<String> export({
    required HrReportPeriod period,
    String? employeeId,
  }) async {
    final result = await GoogleWorkspaceService().generateHrPeriodSheet(
      start: period.start,
      end: period.end,
      employeeId: employeeId,
    );
    return result.resourceId;
  }

  @override
  Future<HrPeriodReport> load({
    required UserModel reviewer,
    required HrReportPeriod period,
  }) async {
    final dates = List<DateTime>.generate(
      period.days,
      (index) => period.start.add(Duration(days: index)),
    );
    final details = <DashboardAttendanceDayDetails>[];
    // Three day reads in flight keeps mobile/web responsive without unbounded
    // request fan-out for the allowed 31-day period.
    for (var index = 0; index < dates.length; index += 3) {
      final end = (index + 3).clamp(0, dates.length);
      details.addAll(
        await Future.wait(
          dates
              .sublist(index, end)
              .map((date) => _attendance.loadDayDetails(reviewer, date)),
        ),
      );
    }
    final auxiliary = await _loadAuxiliary(period);
    final rawAttendance = auxiliary.attendance;
    final employees = <String, HrReportEmployee>{};
    final records = <HrAttendanceRecord>[];
    for (final day in details) {
      for (final person in day.people) {
        final employee = HrReportEmployee(
          id: person.employee.uid,
          name: person.employee.displayName,
          code: person.employee.employeeId,
          department: person.employee.department,
        );
        employees[employee.id] = employee;
        final raw = rawAttendance['${employee.id}:${_key(day.summary.date)}'];
        records.add(
          HrAttendanceRecord(
            employee: employee,
            date: day.summary.date,
            status: person.status,
            checkIn: person.checkInTime,
            checkOut: person.checkOutTime,
            lateMinutes: person.lateMinutes,
            deductionReason:
                _string(raw?['salaryDeductionReason']) ??
                _string(raw?['deductionReason']),
            deductionStatus: _string(raw?['salaryDeductionApprovalStatus']),
          ),
        );
      }
    }
    final employeeList =
        employees.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    final employeeById = {
      for (final employee in employeeList) employee.id: employee,
    };
    final requests = _requestRecords(
      auxiliary.permissions,
      auxiliary.leaves,
      employeeById,
      period,
    );
    final deductions = _deductionRecords(
      auxiliary.attendance.values,
      auxiliary.permissions,
      auxiliary.manualDeductions,
      employeeById,
      period,
    );
    return HrPeriodReport(
      period: period,
      records: records,
      employees: employeeList,
      requests: requests,
      deductions: deductions,
    );
  }

  Future<_ReportAuxiliary> _loadAuxiliary(HrReportPeriod period) async {
    final startKey = _key(period.start);
    final endKey = _key(period.end);
    final endOfPeriod = Timestamp.fromDate(
      DateTime(period.end.year, period.end.month, period.end.day, 23, 59, 59),
    );
    final values = await Future.wait([
      _firestore
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: endKey)
          .get(),
      _firestore
          .collection('permissions')
          .where('requestDate', isGreaterThanOrEqualTo: startKey)
          .where('requestDate', isLessThanOrEqualTo: endKey)
          .limit(5000)
          .get(),
      _firestore
          .collection('leaves')
          .where('status', isEqualTo: 'approved')
          .where('startDate', isLessThanOrEqualTo: endOfPeriod)
          .limit(5000)
          .get(),
      _firestore
          .collection('manual_deductions')
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThanOrEqualTo: endKey)
          .limit(5000)
          .get(),
    ]);
    final attendance = values[0];
    return _ReportAuxiliary(
      attendance: {
        for (final doc in attendance.docs)
          '${doc.data()['userId'] ?? ''}:${doc.data()['date'] ?? ''}':
              doc.data(),
      },
      permissions: values[1].docs.map((doc) => doc.data()).toList(),
      leaves: values[2].docs.map((doc) => doc.data()).toList(),
      manualDeductions: values[3].docs.map((doc) => doc.data()).toList(),
    );
  }

  List<HrRequestRecord> _requestRecords(
    List<Map<String, dynamic>> permissions,
    List<Map<String, dynamic>> leaves,
    Map<String, HrReportEmployee> users,
    HrReportPeriod period,
  ) {
    final output = <HrRequestRecord>[];
    for (final item in permissions) {
      final employee = users[item['userId']];
      final date = _date(item['requestDate']);
      if (employee != null && date != null) {
        output.add(
          HrRequestRecord(
            employee: employee,
            date: date,
            type: 'إذن',
            status: _status(item['status']),
            reason: _string(item['reason']),
          ),
        );
      }
    }
    for (final item in leaves) {
      final employee = users[item['userId']];
      final start = _date(item['startDate']);
      final end = _date(item['endDate']);
      if (employee != null &&
          start != null &&
          end != null &&
          !end.isBefore(period.start) &&
          !start.isAfter(period.end)) {
        output.add(
          HrRequestRecord(
            employee: employee,
            date: start,
            endDate: end,
            type: 'إجازة',
            status: _status(item['status']),
            reason: _string(item['reason']),
          ),
        );
      }
    }
    output.sort((a, b) => b.date.compareTo(a.date));
    return output;
  }

  List<HrDeductionRecord> _deductionRecords(
    Iterable<Map<String, dynamic>> attendance,
    List<Map<String, dynamic>> permissions,
    List<Map<String, dynamic>> manual,
    Map<String, HrReportEmployee> users,
    HrReportPeriod period,
  ) {
    final output = <HrDeductionRecord>[];
    void add(Map<String, dynamic> item, String source, Object? dateValue) {
      final employee = users[item['userId']];
      final date = _date(dateValue);
      final fraction =
          (item['salaryDeductionFraction'] as num?)?.toDouble() ??
          (item['fraction'] as num?)?.toDouble() ??
          0;
      final amount =
          (item['salaryDeductionAmount'] as num?)?.toDouble() ??
          (item['amount'] as num?)?.toDouble() ??
          0;
      final status = _status(
        item['salaryDeductionApprovalStatus'] ?? item['status'],
      );
      if (employee == null ||
          date == null ||
          date.isBefore(period.start) ||
          date.isAfter(period.end) ||
          (fraction <= 0 && amount <= 0 && status == 'none')) {
        return;
      }
      output.add(
        HrDeductionRecord(
          employee: employee,
          date: date,
          reason:
              _string(item['salaryDeductionLabel']) ??
              _string(item['reason']) ??
              'خصم راتب',
          status: status,
          amount: amount,
          fraction: fraction,
          source: source,
        ),
      );
    }

    for (final item in attendance) {
      add(item, 'الحضور والانصراف', item['date']);
    }
    for (final item in permissions) {
      add(item, 'إذن', item['requestDate']);
    }
    for (final item in manual) {
      add(item, 'خصم إداري', item['dateKey']);
    }
    output.sort((a, b) => b.date.compareTo(a.date));
    return output;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return DateTime(
        value.toDate().year,
        value.toDate().month,
        value.toDate().day,
      );
    }
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is String) {
      return DateTime.tryParse(
        value.length >= 10 ? value.substring(0, 10) : value,
      );
    }
    return null;
  }

  String _status(Object? value) =>
      value?.toString().trim().isEmpty ?? true
          ? 'pending'
          : value.toString().trim();

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String? _string(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _ReportAuxiliary {
  const _ReportAuxiliary({
    required this.attendance,
    required this.permissions,
    required this.leaves,
    required this.manualDeductions,
  });
  final Map<String, Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> permissions;
  final List<Map<String, dynamic>> leaves;
  final List<Map<String, dynamic>> manualDeductions;
}
