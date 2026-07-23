class PermissionTypePolicy {
  static const String earlyLeave = 'early_leave';
  static const String lateArrival = 'late_arrival';
  static const String midShiftExit = 'mid_shift_exit';
  static const int regularPermissionCountLimit = 2;
  static const double regularPermissionHoursLimit = 5;
  static const int minimumDurationHours = 1;
  static const int maximumDurationHours = 4;

  static bool isRegularQuotaExhausted({
    required int usedCount,
    required double usedHours,
  }) {
    return usedCount >= regularPermissionCountLimit ||
        usedHours >= regularPermissionHoursLimit;
  }

  static bool exceedsRemainingRegularHours({
    required double usedHours,
    required int requestedMinutes,
  }) {
    return usedHours + (requestedMinutes / 60) > regularPermissionHoursLimit;
  }

  static double deductibleDayFraction(int durationMinutes) {
    if (durationMinutes <= 0 || durationMinutes > maximumDurationHours * 60) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        'Permission duration must be between 1 and 4 hours.',
      );
    }
    return durationMinutes <= 2 * 60 ? 0.25 : 0.5;
  }

  static String deductionCode(int durationMinutes) {
    return deductibleDayFraction(durationMinutes) == 0.25
        ? 'deductible_permission_quarter_day'
        : 'deductible_permission_half_day';
  }

  static String deductionLabel(int durationMinutes) {
    return deductibleDayFraction(durationMinutes) == 0.25
        ? 'خصم ربع يوم - إذن استقطاعي'
        : 'خصم نصف يوم - إذن استقطاعي';
  }

  static String arabicLabel(String type) {
    switch (type) {
      case lateArrival:
        return 'تأخير حضور';
      case midShiftExit:
        return 'مغادرة والعودة أثناء الدوام';
      default:
        return 'مغادرة مبكرة';
    }
  }
}
