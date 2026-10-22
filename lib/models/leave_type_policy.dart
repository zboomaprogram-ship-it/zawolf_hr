class LeaveTypePolicy {
  static const String normal = 'day_off';
  static const String sick = 'sick';
  static const String casual = 'casual';
  static const String unpaid = 'unpaid';
  static const String exam = 'exam';
  static const String paternity = 'paternity';
  static const String special = paternity;
  static const String remote = 'remote';

  static const Set<String> supportedTypes = {
    normal,
    sick,
    casual,
    unpaid,
    exam,
    paternity,
    remote,
  };

  static bool isSupported(String type) => type.trim().isNotEmpty;

  static String normalize(String? type) {
    if (type == null) return normal;
    if (isNormal(type)) return normal;
    if (isSick(type)) return sick;
    if (isCasual(type)) return casual;
    if (isUnpaid(type)) return unpaid;
    if (isExam(type)) return exam;
    if (isRemote(type)) return remote;
    if (type == paternity ||
        type == special ||
        type == 'إجازة خاصة' ||
        type == 'خاصة' ||
        type == 'إجازة حج / عمرة' ||
        type == 'إجازة وضع / رعاية') {
      return paternity;
    }
    return type.trim();
  }

  static bool isNormal(String type) {
    return type == normal ||
        type == 'day_off' ||
        type == 'annual' ||
        type == 'إجازة عادية' ||
        type == 'إجازة سنوية (اعتيادية)';
  }

  static bool isCasual(String type) {
    return type == casual || type == 'إجازة عارضة';
  }

  static bool isSick(String type) {
    return type == sick || type == 'إجازة مرضية';
  }

  static bool isUnpaid(String type) {
    return type == unpaid || type == 'إجازة بدون راتب';
  }

  static bool isExam(String type) {
    return type == exam || type == 'إجازة امتحان' || type == 'امتحان';
  }

  static bool isRemote(String type) {
    return type == remote || type == 'عمل عن بعد' || type == 'يوم عمل عن بعد';
  }

  static String arabicLabel(String type) {
    if (isNormal(type)) return 'إجازة عادية';
    if (isSick(type)) return 'إجازة مرضية';
    if (isCasual(type)) return 'إجازة عارضة';
    if (isUnpaid(type)) return 'إجازة بدون راتب';
    if (isExam(type)) return 'إجازة امتحان';
    if (isRemote(type)) return 'يوم عمل عن بعد';
    switch (type) {
      case paternity:
        return 'إجازة خاصة';
      default:
        return type.isNotEmpty ? type : 'إجازة';
    }
  }

  static String description(String type) {
    switch (type) {
      case normal:
        return 'تُخصم من رصيد أيام الإجازة ويجب تقديمها قبل يومين على الأقل.';
      case sick:
        return 'لا تُخصم من رصيد الإجازات ولا يترتب عليها خصم راتب.';
      case casual:
        return 'متاحة حتى صباح اليوم. تُخصم من رصيد العارضة (7 أيام) ومن رصيد الإجازات الكلي.';
      case unpaid:
        return 'لا تُخصم من رصيد الإجازات، ويُقترح خصم راتب يوم كامل عن كل يوم بعد موافقة HR.';
      case exam:
        return 'لا تُخصم من الرصيد؛ تتطلب إخطاراً قبل 10 أيام وإرفاق ما يثبت الامتحان.';
      case paternity:
        return 'إجازة مدفوعة للمناسبات والظروف الخاصة (زواج، مولود، إلخ)، لا تُخصم من الرصيد وتخضع لموافقة الإدارة.';
      case remote:
        return 'يوم عمل عن بعد لا يُخصم من رصيد الإجازات ولا من الراتب.';
      default:
        return '';
    }
  }

  static String? balanceKey(String type) {
    if (isNormal(type)) return 'daysOff';
    if (isCasual(type)) return 'casual';
    return null;
  }

  static List<String> balanceKeys(String type) {
    if (isNormal(type)) return const ['daysOff'];
    if (isCasual(type)) return const ['casual', 'daysOff'];
    return const [];
  }

  static bool get requiresReason => true;
  static bool requiresNotice(String type, {int noticeDays = 2}) =>
      isNormal(type) && noticeDays > 0;
  static bool requiresTwoDayNotice(String type) => requiresNotice(type, noticeDays: 2);
  static bool requiresFullDaySalaryDeduction(String type) => isUnpaid(type);

  /// Dynamic CEO approval evaluation.
  /// If [thresholdDays] is > 0, leaves with days >= [thresholdDays] require CEO.
  /// If [requireForRemote] is true, remote work requires CEO.
  static bool requiresCeoApproval(
    String type,
    int numberOfDays, {
    int thresholdDays = 3,
    bool requireForRemote = true,
  }) {
    if (requireForRemote && type == remote) return true;
    if (thresholdDays > 0 && numberOfDays >= thresholdDays) return true;
    return false;
  }
}
