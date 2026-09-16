final class EarlyLeaveDeductionPolicy {
  const EarlyLeaveDeductionPolicy._();

  static const Set<int> supportedMinutes = {60, 120, 180, 240};

  static bool supports(int requestedMinutes) =>
      supportedMinutes.contains(requestedMinutes);

  static double dayFraction(int requestedMinutes) {
    if (!supports(requestedMinutes)) {
      throw ArgumentError.value(
        requestedMinutes,
        'requestedMinutes',
        'Early leave must be one to four whole hours.',
      );
    }
    return (requestedMinutes ~/ 60) * 0.25;
  }

  static String fractionLabel(double fraction) => switch (fraction) {
    0.25 => 'ربع يوم',
    0.5 => 'نصف يوم',
    0.75 => 'ثلاثة أرباع يوم',
    _ => 'يوم كامل',
  };
}
