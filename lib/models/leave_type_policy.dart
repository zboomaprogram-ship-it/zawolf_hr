class LeaveTypePolicy {
  static const String normal = 'day_off';
  static const String sick = 'sick';
  static const String casual = 'casual';
  static const String unpaid = 'unpaid';
  static const String exam = 'exam';
  static const String paternity = 'paternity';
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
        return 'إجازة مولود';
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
        return 'إجازة مدفوعة يوم الولادة، لا تُخصم من الرصيد، وبحد أقصى 3 مرات طوال الخدمة.';
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
  static bool requiresTwoDayNotice(String type) => type == normal;
  static bool requiresFullDaySalaryDeduction(String type) => type == unpaid;

  /// Three chargeable workdays or more require the employee's assigned CEO.
  /// The leave service calculates chargeable days before this policy is used,
  /// so Fridays and active company holidays never create an extra approval.
  static bool requiresCeoApproval(String type, int numberOfDays) =>
      type == remote || numberOfDays >= 3;
}
