class PermissionTypePolicy {
  static const String earlyLeave = 'early_leave';
  static const String lateArrival = 'late_arrival';
  static const String midShiftExit = 'mid_shift_exit';
  static const int regularPermissionCountLimit = 2;
  static const double regularPermissionHoursLimit = 5;
  static const int minimumDurationHours = 1;
  static const int maximumDurationHours = 4;

  static bool isLateArrival(String type) {
    return type == lateArrival ||
        type == 'إذن تأخير صباحي' ||
        type == 'تأخير حضور';
  }

  static bool isEarlyLeave(String type) {
    return type == earlyLeave ||
        type == 'إذن انصراف مبكر' ||
        type == 'مغادرة مبكرة';
  }

  static bool isMidShiftExit(String type) {
    return type == midShiftExit ||
        type == 'إذن خروج مؤقت أثناء العمل' ||
        type == 'مغادرة والعودة' ||
        type == 'مغادرة والعودة أثناء الدوام';
  }

  static int resolveExpectedMinutes({
    required String permissionType,
    required int durationMinutes,
    required int workStartMinutes,
    required int workEndMinutes,
    required int selectedMinutes,
  }) {
    if (durationMinutes < minimumDurationHours * 60 ||
        durationMinutes > maximumDurationHours * 60) {
      throw ArgumentError.value(durationMinutes, 'durationMinutes');
    }
    if (isLateArrival(permissionType)) {
      return (workStartMinutes + durationMinutes).clamp(0, 1439);
    }
    if (isEarlyLeave(permissionType)) {
      return (workEndMinutes - durationMinutes).clamp(0, 1439);
    }
    return selectedMinutes.clamp(0, 1439);
  }

  static bool isRegularQuotaExhausted({
    required int usedCount,
    required double usedHours,
    int countLimit = regularPermissionCountLimit,
    double hoursLimit = regularPermissionHoursLimit,
  }) {
    return usedCount >= countLimit || usedHours >= hoursLimit;
  }

  static bool exceedsRemainingRegularHours({
    required double usedHours,
    required int requestedMinutes,
    double hoursLimit = regularPermissionHoursLimit,
  }) {
    return usedHours + (requestedMinutes / 60) > hoursLimit;
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
    if (isLateArrival(type)) return 'تأخير حضور';
    if (isMidShiftExit(type)) return 'مغادرة والعودة أثناء الدوام';
    if (isEarlyLeave(type)) return 'مغادرة مبكرة';
    return type.isNotEmpty ? type : 'إذن';
  }
}
