class LeaveEntitlementPolicy {
  static const int defaultAnnualQuota = 15;
  static const int defaultCasualQuota = 7;
  static const int probationMonths = 6;

  static DateTime addMonths(DateTime date, int months) {
    final targetMonth = date.month - 1 + months;
    final year = date.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day.clamp(1, lastDay));
  }

  static DateTime? eligibleFrom(DateTime? hiringDate) {
    if (hiringDate == null) return null;
    return addMonths(hiringDate, probationMonths);
  }

  static bool isOnProbation(DateTime? hiringDate, {DateTime? onDate}) {
    final eligibilityDate = eligibleFrom(hiringDate);
    if (eligibilityDate == null) return true;
    return (onDate ?? DateTime.now()).isBefore(eligibilityDate);
  }

  static int calculateAnnualQuota({
    required DateTime hiringDate,
    DateTime? birthDate,
    DateTime? asOfDate,
  }) {
    final on = asOfDate ?? DateTime.now();
    int fullYears(DateTime date) {
      var years = on.year - date.year;
      if (DateTime(on.year, date.month, date.day).isAfter(on)) years--;
      return years;
    }

    final serviceYears = fullYears(hiringDate);
    final age = birthDate == null ? -1 : fullYears(birthDate);
    if (serviceYears >= 10 || age >= 50) return 30;
    return serviceYears >= 1 ? 21 : 15;
  }
}
