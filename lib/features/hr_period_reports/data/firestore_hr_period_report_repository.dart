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
final class FirestoreHrPeriodReportRepository implements HrPeriodReportRepository {
  FirestoreHrPeriodReportRepository({DashboardAttendanceSummaryService? attendance, FirebaseFirestore? firestore})
      : _attendance = attendance ?? DashboardAttendanceSummaryService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final DashboardAttendanceSummaryService _attendance;
  final FirebaseFirestore _firestore;

  @override
  Future<String> export({required HrReportPeriod period, String? employeeId}) async {
    final result = await GoogleWorkspaceService().generateHrPeriodSheet(
      start: period.start,
      end: period.end,
      employeeId: employeeId,
    );
    return result.resourceId;
  }

  @override
  Future<HrPeriodReport> load({required UserModel reviewer, required HrReportPeriod period}) async {
    final dates = List<DateTime>.generate(period.days, (index) => period.start.add(Duration(days: index)));
    final details = <DashboardAttendanceDayDetails>[];
    // Three day reads in flight keeps mobile/web responsive without unbounded
    // request fan-out for the allowed 31-day period.
    for (var index = 0; index < dates.length; index += 3) {
      final end = (index + 3).clamp(0, dates.length);
      details.addAll(await Future.wait(dates.sublist(index, end).map((date) => _attendance.loadDayDetails(reviewer, date))));
    }
    final rawAttendance = await _loadAttendanceMetadata(period);
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
        records.add(HrAttendanceRecord(
          employee: employee,
          date: day.summary.date,
          status: person.status,
          checkIn: person.checkInTime,
          checkOut: person.checkOutTime,
          lateMinutes: person.lateMinutes,
          deductionReason: _string(raw?['salaryDeductionReason']) ?? _string(raw?['deductionReason']),
          deductionStatus: _string(raw?['salaryDeductionApprovalStatus']),
        ));
      }
    }
    return HrPeriodReport(
      period: period,
      records: records,
      employees: employees.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadAttendanceMetadata(HrReportPeriod period) async {
    final snapshot = await _firestore.collection('attendance')
        .where('date', isGreaterThanOrEqualTo: _key(period.start))
        .where('date', isLessThanOrEqualTo: _key(period.end))
        .get();
    return {
      for (final doc in snapshot.docs)
        '${doc.data()['userId'] ?? ''}:${doc.data()['date'] ?? ''}': doc.data(),
    };
  }

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String? _string(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
