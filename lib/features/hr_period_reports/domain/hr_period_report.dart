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
  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class HrReportEmployee {
  const HrReportEmployee({
    required this.id,
    required this.name,
    required this.code,
    required this.department,
    this.baseMonthlySalary = 0,
    this.salaryCurrency = 'EGP',
  });
  final String id;
  final String name;
  final String code;
  final String department;
  final double baseMonthlySalary;
  final String salaryCurrency;
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
    this.statusDetail,
  });
  final HrReportEmployee employee;
  final DateTime date;
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int lateMinutes;
  final String? deductionReason;
  final String? deductionStatus;
  final String? statusDetail;

  bool get approvedDeduction => deductionStatus == 'approved';
}

class HrPeriodReport {
  const HrPeriodReport({
    required this.period,
    required this.records,
    required this.employees,
    this.requests = const [],
    this.deductions = const [],
  });
  final HrReportPeriod period;
  final List<HrAttendanceRecord> records;
  final List<HrReportEmployee> employees;
  final List<HrRequestRecord> requests;
  final List<HrDeductionRecord> deductions;

  List<HrAttendanceRecord> forEmployee(String? employeeId) =>
      employeeId == null
          ? records
          : records
              .where((record) => record.employee.id == employeeId)
              .toList();
  List<HrRequestRecord> requestsForEmployee(String? employeeId) =>
      employeeId == null
          ? requests
          : requests
              .where((record) => record.employee.id == employeeId)
              .toList();
  List<HrDeductionRecord> deductionsForEmployee(String? employeeId) =>
      employeeId == null
          ? deductions
          : deductions
              .where((record) => record.employee.id == employeeId)
              .toList();
}

class HrRequestRecord {
  const HrRequestRecord({
    required this.employee,
    required this.date,
    required this.type,
    required this.status,
    this.reason,
    this.endDate,
  });
  final HrReportEmployee employee;
  final DateTime date;
  final DateTime? endDate;
  final String type;
  final String status;
  final String? reason;
}

class HrDeductionRecord {
  const HrDeductionRecord({
    required this.employee,
    required this.date,
    required this.reason,
    required this.status,
    this.amount = 0,
    this.fraction = 0,
    this.source = 'attendance',
    this.detail,
  });
  final HrReportEmployee employee;
  final DateTime date;
  final String reason;
  final String status;
  final double amount;
  final double fraction;
  final String source;
  final String? detail;
  bool get affectsDiscipline => status == 'approved';

  double resolvedAmount({int payrollWorkDaysPerMonth = 26}) {
    if (amount > 0) return amount;
    if (fraction <= 0 || employee.baseMonthlySalary <= 0) return 0;
    return employee.baseMonthlySalary / payrollWorkDaysPerMonth * fraction;
  }
}

class HrAttendanceTrendPoint {
  const HrAttendanceTrendPoint({
    required this.date,
    required this.scheduled,
    required this.attended,
    required this.late,
  });

  final DateTime date;
  final int scheduled;
  final int attended;
  final int late;

  double get attendanceRate => scheduled == 0 ? 0 : attended / scheduled;
  double get lateRate => scheduled == 0 ? 0 : late / scheduled;
}

extension HrPeriodReportAnalysis on HrPeriodReport {
  List<HrAttendanceTrendPoint> trendForEmployee(String? employeeId) {
    final selected = forEmployee(employeeId);
    return List.generate(period.days, (index) {
      final date = period.start.add(Duration(days: index));
      final day = selected.where(
        (record) =>
            record.date.year == date.year &&
            record.date.month == date.month &&
            record.date.day == date.day,
      );
      final scheduled =
          day.where((record) => record.status != 'day_off').toList();
      return HrAttendanceTrendPoint(
        date: date,
        scheduled: scheduled.length,
        attended:
            scheduled
                .where(
                  (record) => const {
                    'present',
                    'late',
                    'permission',
                    'field_mission',
                  }.contains(record.status),
                )
                .length,
        late: scheduled.where((record) => record.status == 'late').length,
      );
    });
  }
}
