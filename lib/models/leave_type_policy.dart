class LeaveTypePolicy {
  static const String normal = 'day_off';
  static const String sick = 'sick';
  static const String casual = 'casual';
  static const String unpaid = 'unpaid';
  static const String exam = 'exam';

  static const Set<String> supportedTypes = {
    normal,
    sick,
    casual,
    unpaid,
    exam,
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
        return 'متاحة حتى صباح اليوم وتُخصم من رصيد الإجازات العارضة.';
      case unpaid:
        return 'لا تُخصم من رصيد الإجازات، ويُقترح خصم راتب يوم كامل عن كل يوم بعد موافقة HR.';
      case exam:
        return 'لا تُخصم من رصيد الإجازات ولا من الراتب، ويجب كتابة سبب الامتحان.';
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

  static bool get requiresReason => true;
  static bool requiresTwoDayNotice(String type) => type == normal;
  static bool requiresFullDaySalaryDeduction(String type) => type == unpaid;
}
