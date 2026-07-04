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
  static const String defaultStartTime = '09:00';
  static const String defaultEndTime = '17:00';
  static const List<int> saturdayToThursdayWorkDays = [6, 7, 1, 2, 3, 4];
  static const int defaultPayrollWorkDaysPerMonth = 26;

  static DateTime parseTimeOnDate(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static AttendanceDeduction evaluateLateArrival({
    required DateTime arrivalTime,
    String startTime = defaultStartTime,
  }) {
    final shiftStart = parseTimeOnDate(arrivalTime, startTime);
    final lateMinutes = arrivalTime.isAfter(shiftStart)
        ? arrivalTime.difference(shiftStart).inMinutes
        : 0;

    if (lateMinutes <= 15) {
      return AttendanceDeduction(
        dayFraction: 0,
        code: 'none',
        arabicLabel: 'لا يوجد خصم',
        status: 'present',
        isLate: false,
        lateMinutes: lateMinutes,
      );
    }

    if (lateMinutes <= 30) {
      return AttendanceDeduction(
        dayFraction: 0.25,
        code: 'quarter_day',
        arabicLabel: 'خصم ربع يوم',
        status: 'late_quarter_day',
        isLate: true,
        lateMinutes: lateMinutes,
      );
    }

    if (lateMinutes <= 60) {
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
