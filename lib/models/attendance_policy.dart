class AttendanceDeduction {
  final double dayFraction;
  final String code;
  final String arabicLabel;
  final String status;
  final bool isLate;
  final int lateMinutes;

  const AttendanceDeduction({
    required this.dayFraction,
    required this.code,
    required this.arabicLabel,
    required this.status,
    required this.isLate,
    required this.lateMinutes,
  });
}

class AttendancePolicy {
  static const String defaultCheckInOpenTime = '07:00';
  static const String defaultStartTime = '09:00';
  static const String defaultEndTime = '17:00';
  static const String defaultLatestCheckoutTime = '23:00';
  static const List<int> saturdayToThursdayWorkDays = [6, 7, 1, 2, 3, 4];
  static const int defaultPayrollWorkDaysPerMonth = 26;
  static const int defaultGraceMinutes = 15;
  static const int defaultQuarterDayUntilMinutes = 30;
  static const int defaultHalfDayUntilMinutes = 60;

  static DateTime parseTimeOnDate(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static AttendanceDeduction evaluateLateArrival({
    required DateTime arrivalTime,
    String startTime = defaultStartTime,
    int graceMinutes = defaultGraceMinutes,
    int quarterDayUntilMinutes = defaultQuarterDayUntilMinutes,
    int halfDayUntilMinutes = defaultHalfDayUntilMinutes,
  }) {
    final shiftStart = parseTimeOnDate(arrivalTime, startTime);
    final lateMinutes = arrivalTime.isAfter(shiftStart)
        ? arrivalTime.difference(shiftStart).inMinutes
        : 0;

    if (lateMinutes <= graceMinutes) {
      return AttendanceDeduction(
        dayFraction: 0,
        code: 'none',
        arabicLabel: 'لا يوجد خصم',
        status: 'present',
        isLate: false,
        lateMinutes: lateMinutes,
      );
    }

    if (lateMinutes <= quarterDayUntilMinutes) {
      return AttendanceDeduction(
        dayFraction: 0.25,
        code: 'quarter_day',
        arabicLabel: 'خصم ربع يوم',
        status: 'late_quarter_day',
        isLate: true,
        lateMinutes: lateMinutes,
      );
    }

    if (lateMinutes <= halfDayUntilMinutes) {
      return AttendanceDeduction(
        dayFraction: 0.5,
        code: 'half_day',
        arabicLabel: 'خصم نصف يوم',
        status: 'late_half_day',
        isLate: true,
        lateMinutes: lateMinutes,
      );
    }

    return AttendanceDeduction(
      dayFraction: 1,
      code: 'full_day',
      arabicLabel: 'خصم يوم كامل',
      status: 'late_full_day',
      isLate: true,
      lateMinutes: lateMinutes,
    );
  }

  static double calculateSalaryDeductionAmount({
    required double monthlySalary,
    required double dayFraction,
    int payrollWorkDaysPerMonth = defaultPayrollWorkDaysPerMonth,
  }) {
    if (monthlySalary <= 0 || dayFraction <= 0) return 0;
    return (monthlySalary / payrollWorkDaysPerMonth) * dayFraction;
  }
}

class AttendancePolicyConfig {
  final String checkInOpenTime;
  final String defaultStartTime;
  final String defaultEndTime;
  final String latestCheckoutTime;
  final int graceMinutes;
  final int quarterDayUntilMinutes;
  final int halfDayUntilMinutes;
  final int payrollWorkDaysPerMonth;

  const AttendancePolicyConfig({
    this.checkInOpenTime = AttendancePolicy.defaultCheckInOpenTime,
    this.defaultStartTime = AttendancePolicy.defaultStartTime,
    this.defaultEndTime = AttendancePolicy.defaultEndTime,
    this.latestCheckoutTime = AttendancePolicy.defaultLatestCheckoutTime,
    this.graceMinutes = AttendancePolicy.defaultGraceMinutes,
    this.quarterDayUntilMinutes =
        AttendancePolicy.defaultQuarterDayUntilMinutes,
    this.halfDayUntilMinutes = AttendancePolicy.defaultHalfDayUntilMinutes,
    this.payrollWorkDaysPerMonth =
        AttendancePolicy.defaultPayrollWorkDaysPerMonth,
  });

  factory AttendancePolicyConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AttendancePolicyConfig();

    int readInt(String key, int fallback) {
      final value = map[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return AttendancePolicyConfig(
      checkInOpenTime:
          map['checkInOpenTime'] as String? ??
          AttendancePolicy.defaultCheckInOpenTime,
      defaultStartTime:
          map['defaultStartTime'] as String? ??
          map['startTime'] as String? ??
          AttendancePolicy.defaultStartTime,
      defaultEndTime:
          map['defaultEndTime'] as String? ??
          map['endTime'] as String? ??
          AttendancePolicy.defaultEndTime,
      latestCheckoutTime:
          map['latestCheckoutTime'] as String? ??
          AttendancePolicy.defaultLatestCheckoutTime,
      graceMinutes: readInt(
        'graceMinutes',
        AttendancePolicy.defaultGraceMinutes,
      ),
      quarterDayUntilMinutes: readInt(
        'quarterDayUntilMinutes',
        AttendancePolicy.defaultQuarterDayUntilMinutes,
      ),
      halfDayUntilMinutes: readInt(
        'halfDayUntilMinutes',
        AttendancePolicy.defaultHalfDayUntilMinutes,
      ),
      payrollWorkDaysPerMonth: readInt(
        'payrollWorkDaysPerMonth',
        AttendancePolicy.defaultPayrollWorkDaysPerMonth,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkInOpenTime': checkInOpenTime,
      'defaultStartTime': defaultStartTime,
      'defaultEndTime': defaultEndTime,
      'latestCheckoutTime': latestCheckoutTime,
      'graceMinutes': graceMinutes,
      'quarterDayUntilMinutes': quarterDayUntilMinutes,
      'halfDayUntilMinutes': halfDayUntilMinutes,
      'payrollWorkDaysPerMonth': payrollWorkDaysPerMonth,
    };
  }

  AttendanceDeduction evaluateLateArrival({
    required DateTime arrivalTime,
    String? employeeStartTime,
  }) {
    return AttendancePolicy.evaluateLateArrival(
      arrivalTime: arrivalTime,
      startTime: employeeStartTime ?? defaultStartTime,
      graceMinutes: graceMinutes,
      quarterDayUntilMinutes: quarterDayUntilMinutes,
      halfDayUntilMinutes: halfDayUntilMinutes,
    );
  }

  double calculateSalaryDeductionAmount({
    required double monthlySalary,
    required double dayFraction,
  }) {
    return AttendancePolicy.calculateSalaryDeductionAmount(
      monthlySalary: monthlySalary,
      dayFraction: dayFraction,
      payrollWorkDaysPerMonth: payrollWorkDaysPerMonth,
    );
  }
}
