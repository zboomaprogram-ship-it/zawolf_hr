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

  static String arabicLabel(String type) {
    switch (type) {
      case normal:
        return 'إجازة عادية';
      case sick:
        return 'إجازة مرضية';
      case casual:
        return 'إجازة عارضة';
      case unpaid:
        return 'إجازة بدون راتب';
      case exam:
        return 'إجازة امتحان';
      case paternity:
        return 'إجازة خاصة';
      case remote:
        return 'يوم عمل عن بعد';
      default:
        return type;
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
    switch (type) {
      case normal:
        return 'daysOff';
      case casual:
        return 'casual';
      default:
        return null;
    }
  }

  static List<String> balanceKeys(String type) {
    switch (type) {
      case normal:
        return const ['daysOff'];
      case casual:
        return const ['casual', 'daysOff'];
      default:
        return const [];
    }
  }

  static bool get requiresReason => true;
  static bool requiresNotice(String type, {int noticeDays = 2}) =>
      type == normal && noticeDays > 0;
  static bool requiresTwoDayNotice(String type) => requiresNotice(type, noticeDays: 2);
  static bool requiresFullDaySalaryDeduction(String type) => type == unpaid;

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
