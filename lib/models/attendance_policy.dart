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

  /// Storage codes must stay stable for payroll reconciliation, but they must
  /// never be shown as English/internal values to an employee.
  static String arabicDeductionLabel(String code, {String? fallback}) {
    switch (code.trim().toLowerCase()) {
      case 'late_quarter_day':
      case 'quarter_day':
        return 'خصم ربع يوم بسبب التأخير';
      case 'late_half_day':
      case 'half_day':
        return 'خصم نصف يوم بسبب التأخير';
      case 'late_full_day':
      case 'full_day':
      case 'absence':
      case 'absent':
        return 'خصم يوم كامل';
      case 'missed_checkout_quarter_day':
        return 'خصم ربع يوم لعدم تسجيل الانصراف';
      case 'early_checkout_quarter_day':
        return 'خصم ربع يوم للانصراف المبكر';
      case 'late_checkout_after_11_quarter_day':
        return 'خصم ربع يوم لتأخر تسجيل الانصراف';
      case 'none':
      case '':
        return fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : 'لا يوجد خصم';
      default:
        final value = fallback?.trim() ?? '';
        // Some historical rows wrote an internal code into the display label.
        return value.isNotEmpty && !RegExp(r'^[a-z0-9_ -]+$').hasMatch(value)
            ? value
            : 'خصم راتب يحتاج مراجعة الموارد البشرية';
    }
  }

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
    final lateMinutes =
        arrivalTime.isAfter(shiftStart)
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
  final int checkInReminderLeadMinutes;
  final int checkInLateWarningMinutes;
  final int checkInFinalWarningLeadMinutes;

  /// `location_only` is the company attendance mode. It keeps the device,
  /// root, mock-location, and geofence checks but skips the biometric prompt.
  final String attendanceVerificationMode;

  /// Policy-defined remote-work business settings stored with the shared
  /// attendance policy. Empty means no remote-work policy has been configured.
  /// Unknown extension fields are retained so older dashboard builds do not
  /// erase settings added by a newer policy schema.
  final Map<String, dynamic> remoteWorkPolicy;

  /// Unknown shared-policy extensions survive load/edit/save by older builds.
  final Map<String, dynamic> extensionFields;

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
    this.checkInReminderLeadMinutes = 10,
    this.checkInLateWarningMinutes = 10,
    this.checkInFinalWarningLeadMinutes = 5,
    this.attendanceVerificationMode = 'location_only',
    this.remoteWorkPolicy = const {},
    this.extensionFields = const {},
  });

  bool get requiresBiometric => attendanceVerificationMode != 'location_only';

  factory AttendancePolicyConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AttendancePolicyConfig();

    int readInt(String key, int fallback) {
      final value = map[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    const knownFields = {
      'checkInOpenTime',
      'defaultStartTime',
      'startTime',
      'defaultEndTime',
      'endTime',
      'latestCheckoutTime',
      'graceMinutes',
      'quarterDayUntilMinutes',
      'halfDayUntilMinutes',
      'payrollWorkDaysPerMonth',
      'checkInReminderLeadMinutes',
      'checkInLateWarningMinutes',
      'checkInFinalWarningLeadMinutes',
      'attendanceVerificationMode',
      'remoteWorkPolicy',
    };
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
      checkInReminderLeadMinutes: readInt('checkInReminderLeadMinutes', 10),
      checkInLateWarningMinutes: readInt('checkInLateWarningMinutes', 10),
      checkInFinalWarningLeadMinutes: readInt(
        'checkInFinalWarningLeadMinutes',
        5,
      ),
      attendanceVerificationMode:
          map['attendanceVerificationMode'] == 'biometric'
              ? 'biometric'
              : 'location_only',
      remoteWorkPolicy: _copyPolicyMap(
        map['remoteWorkPolicy'] is Map
            ? Map<String, dynamic>.from(map['remoteWorkPolicy'] as Map)
            : const {},
      ),
      extensionFields: _copyPolicyMap({
        for (final entry in map.entries)
          if (!knownFields.contains(entry.key)) entry.key: entry.value,
      }),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ..._copyPolicyMap(extensionFields),
      'checkInOpenTime': checkInOpenTime,
      'defaultStartTime': defaultStartTime,
      'defaultEndTime': defaultEndTime,
      'latestCheckoutTime': latestCheckoutTime,
      'graceMinutes': graceMinutes,
      'quarterDayUntilMinutes': quarterDayUntilMinutes,
      'halfDayUntilMinutes': halfDayUntilMinutes,
      'payrollWorkDaysPerMonth': payrollWorkDaysPerMonth,
      'checkInReminderLeadMinutes': checkInReminderLeadMinutes,
      'checkInLateWarningMinutes': checkInLateWarningMinutes,
      'checkInFinalWarningLeadMinutes': checkInFinalWarningLeadMinutes,
      'attendanceVerificationMode': attendanceVerificationMode,
      'remoteWorkPolicy': _copyPolicyMap(remoteWorkPolicy),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendancePolicyConfig &&
          runtimeType == other.runtimeType &&
          checkInOpenTime == other.checkInOpenTime &&
          defaultStartTime == other.defaultStartTime &&
          defaultEndTime == other.defaultEndTime &&
          latestCheckoutTime == other.latestCheckoutTime &&
          graceMinutes == other.graceMinutes &&
          quarterDayUntilMinutes == other.quarterDayUntilMinutes &&
          halfDayUntilMinutes == other.halfDayUntilMinutes &&
          payrollWorkDaysPerMonth == other.payrollWorkDaysPerMonth &&
          checkInReminderLeadMinutes == other.checkInReminderLeadMinutes &&
          checkInLateWarningMinutes == other.checkInLateWarningMinutes &&
          checkInFinalWarningLeadMinutes ==
              other.checkInFinalWarningLeadMinutes &&
          attendanceVerificationMode == other.attendanceVerificationMode &&
          _policyValueEquals(remoteWorkPolicy, other.remoteWorkPolicy) &&
          _policyValueEquals(extensionFields, other.extensionFields);

  @override
  int get hashCode => Object.hash(
    checkInOpenTime,
    defaultStartTime,
    defaultEndTime,
    latestCheckoutTime,
    graceMinutes,
    quarterDayUntilMinutes,
    halfDayUntilMinutes,
    payrollWorkDaysPerMonth,
    checkInReminderLeadMinutes,
    checkInLateWarningMinutes,
    checkInFinalWarningLeadMinutes,
    attendanceVerificationMode,
    _policyValueHash(remoteWorkPolicy),
    _policyValueHash(extensionFields),
  );
}

Map<String, dynamic> _copyPolicyMap(Map<String, dynamic> value) =>
    value.map((key, nested) => MapEntry(key, _copyPolicyValue(nested)));

dynamic _copyPolicyValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, nested) => MapEntry(key.toString(), _copyPolicyValue(nested)),
    );
  }
  if (value is List) return value.map(_copyPolicyValue).toList();
  return value;
}

bool _policyValueEquals(dynamic left, dynamic right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length ||
        !left.keys.toSet().containsAll(right.keys)) {
      return false;
    }
    return left.keys.every((key) => _policyValueEquals(left[key], right[key]));
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_policyValueEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

int _policyValueHash(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return Object.hashAll(
      keys.map((key) => Object.hash(key, _policyValueHash(value[key]))),
    );
  }
  if (value is List) return Object.hashAll(value.map(_policyValueHash));
  return value.hashCode;
}

/// Pure validation for business-defined remote-work policy values.
///
/// This validates the current client contract only. Publication must repeat
/// validation against the server-owned schema and capability catalog.
class RemoteWorkPolicyValidation {
  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static List<String> validate(Map<String, dynamic> policy) {
    if (policy['enabled'] != true) return const [];
    final errors = <String>[];
    final eligibility = _asMap(policy['eligibility']);
    final daysPerWeek = _asInt(eligibility['daysPerWeek']);
    final weekdays = _asIntList(eligibility['allowedWeekdays']);
    if (daysPerWeek == null ||
        daysPerWeek < 1 ||
        weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7) ||
        weekdays.toSet().length != weekdays.length ||
        daysPerWeek > weekdays.length) {
      errors.add('eligibility.daysPerWeek');
    }
    final weekStartDay = _asInt(eligibility['weekStartDay']);
    if (weekStartDay != null && (weekStartDay < 1 || weekStartDay > 7)) {
      errors.add('eligibility.weekStartDay');
    }
    if (eligibility['carryoverEnabled'] == true) {
      final carryoverCap = _asInt(eligibility['carryoverCap']);
      if (carryoverCap == null || carryoverCap < 1) {
        errors.add('eligibility.carryoverCap');
      }
    }

    final schedule = _asMap(policy['schedule']);
    final endDayOffset = _asInt(schedule['endDayOffset']);
    if (endDayOffset != null && (endDayOffset < 0 || endDayOffset > 1)) {
      errors.add('schedule.endDayOffset');
    }
    final rawCheckpoints = schedule['checkpoints'];
    if (rawCheckpoints != null && rawCheckpoints is! List) {
      errors.add('schedule.checkpoints');
    } else {
      final checkpoints = rawCheckpoints as List? ?? const [];
      final ids = <String>{};
      for (var index = 0; index < checkpoints.length; index++) {
        final checkpoint = _asMap(checkpoints[index]);
        final id = checkpoint['id']?.toString().trim() ?? '';
        if (id.isEmpty || !ids.add(id)) {
          errors.add('schedule.checkpoints[$index].id');
        }
        final dueTime = checkpoint['dueTime']?.toString() ?? '';
        if (!_timePattern.hasMatch(dueTime)) {
          errors.add('schedule.checkpoints[$index].dueTime');
        }
        final grace = _asInt(checkpoint['graceMinutes']);
        if (grace == null || grace < 0) {
          errors.add('schedule.checkpoints[$index].graceMinutes');
        }
      }
    }

    for (final key in const [
      'startTime',
      'endTime',
      'checkInOpenTime',
      'latestCheckoutTime',
    ]) {
      _validateTimeOverride(schedule, key, errors);
    }
    for (final key in const [
      'graceMinutes',
      'quarterDayUntilMinutes',
      'halfDayUntilMinutes',
    ]) {
      final override = schedule[key];
      if (override == null) continue;
      final value = _asMap(override);
      if (value['mode'] != 'inherit' && value['mode'] != 'override') {
        errors.add('schedule.$key.mode');
      } else if (value['mode'] == 'override') {
        final minutes = _asInt(value['value']);
        if (minutes == null || minutes < 0) errors.add('schedule.$key.value');
      }
    }
    return errors;
  }

  static void _validateTimeOverride(
    Map<String, dynamic> schedule,
    String key,
    List<String> errors,
  ) {
    final override = schedule[key];
    if (override == null) return;
    final value = _asMap(override);
    if (value['mode'] != 'inherit' && value['mode'] != 'override') {
      errors.add('schedule.$key.mode');
    } else if (value['mode'] == 'override' &&
        !_timePattern.hasMatch(value['value']?.toString() ?? '')) {
      errors.add('schedule.$key.value');
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static List<int> _asIntList(dynamic value) =>
      value is List ? value.map(_asInt).whereType<int>().toList() : const [];
}
