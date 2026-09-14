class HrReportPeriod {
  const HrReportPeriod._(this.start, this.end);

  factory HrReportPeriod.sevenDays({DateTime? now}) {
    final end = _day(now ?? DateTime.now());
    return HrReportPeriod._(end.subtract(const Duration(days: 6)), end);
  }

  factory HrReportPeriod.thirtyDays({DateTime? now}) {
    final end = _day(now ?? DateTime.now());
    return HrReportPeriod._(end.subtract(const Duration(days: 29)), end);
  }

  factory HrReportPeriod.custom(DateTime start, DateTime end) {
    final first = _day(start);
    final last = _day(end);
    if (last.isBefore(first) || last.difference(first).inDays >= 31) {
      throw ArgumentError('يجب أن تكون الفترة من يوم واحد إلى 31 يوماً.');
    }
    return HrReportPeriod._(first, last);
  }

  final DateTime start;
  final DateTime end;
  int get days => end.difference(start).inDays + 1;
  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}

class HrReportEmployee {
  const HrReportEmployee({required this.id, required this.name, required this.code, required this.department});
  final String id;
  final String name;
  final String code;
  final String department;
}

class HrAttendanceRecord {
  const HrAttendanceRecord({
    required this.employee,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.lateMinutes = 0,
    this.deductionReason,
    this.deductionStatus,
  });
  final HrReportEmployee employee;
  final DateTime date;
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int lateMinutes;
  final String? deductionReason;
  final String? deductionStatus;

  bool get approvedDeduction => deductionStatus == 'approved';
}

class HrPeriodReport {
  const HrPeriodReport({required this.period, required this.records, required this.employees});
  final HrReportPeriod period;
  final List<HrAttendanceRecord> records;
  final List<HrReportEmployee> employees;

  List<HrAttendanceRecord> forEmployee(String? employeeId) => employeeId == null
      ? records
      : records.where((record) => record.employee.id == employeeId).toList();
}
