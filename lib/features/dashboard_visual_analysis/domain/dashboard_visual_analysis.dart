import '../../../services/dashboard_attendance_summary_service.dart';
export '../../../services/dashboard_attendance_summary_service.dart'
    show DashboardAttendanceSummary;

/// An inclusive dashboard range. Custom ranges are bounded to protect Firestore
/// reads and are normalized to calendar days.
enum DashboardPeriodKind { sevenDays, thirtyDays, custom }

class DashboardPeriod {
  const DashboardPeriod._(this.kind, this.start, this.end);

  factory DashboardPeriod.sevenDays({DateTime? now}) {
    final end = _day(now ?? DateTime.now());
    return DashboardPeriod._(DashboardPeriodKind.sevenDays, end.subtract(const Duration(days: 6)), end);
  }

  factory DashboardPeriod.thirtyDays({DateTime? now}) {
    final end = _day(now ?? DateTime.now());
    return DashboardPeriod._(DashboardPeriodKind.thirtyDays, end.subtract(const Duration(days: 29)), end);
  }

  factory DashboardPeriod.custom(DateTime start, DateTime end) {
    final normalizedStart = _day(start);
    final normalizedEnd = _day(end);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError('The end date must not precede the start date.');
    }
    if (normalizedEnd.difference(normalizedStart).inDays + 1 > 31) {
      throw ArgumentError('Custom dashboard ranges are limited to 31 days.');
    }
    return DashboardPeriod._(DashboardPeriodKind.custom, normalizedStart, normalizedEnd);
  }

  final DashboardPeriodKind kind;
  final DateTime start;
  final DateTime end;
  int get dayCount => end.difference(start).inDays + 1;

  static DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
}

class DashboardTaskTotals {
  const DashboardTaskTotals({this.newTasks = 0, this.inProgress = 0, this.late = 0, this.completed = 0});
  final int newTasks;
  final int inProgress;
  final int late;
  final int completed;
  int get requiringAttention => newTasks + late;
}

class DashboardRequestTotals {
  const DashboardRequestTotals({this.leaves = 0, this.permissions = 0, this.advances = 0, this.administrative = 0, this.resignations = 0});
  final int leaves;
  final int permissions;
  final int advances;
  final int administrative;
  final int resignations;
  int get total => leaves + permissions + advances + administrative + resignations;
  Map<String, int> get byCategory => {'leaves': leaves, 'permissions': permissions, 'advances': advances, 'administrative': administrative, 'resignations': resignations};
}

class DashboardDepartmentAttendance {
  const DashboardDepartmentAttendance({required this.department, required this.summary});
  final String department;
  final DashboardAttendanceSummary summary;
}

class DashboardVisualAnalysis {
  const DashboardVisualAnalysis({required this.period, required this.today, required this.trend, required this.tasks, required this.departments});
  final DashboardPeriod period;
  final DashboardAttendanceSummary today;
  final List<DashboardAttendanceSummary> trend;
  final DashboardTaskTotals tasks;
  final List<DashboardDepartmentAttendance> departments;
}
