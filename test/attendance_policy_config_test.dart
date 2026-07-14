import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_policy.dart';

void main() {
  test('policy config keeps configurable reminder thresholds', () {
    final policy = AttendancePolicyConfig.fromMap({
      'defaultStartTime': '09:00',
      'checkInReminderLeadMinutes': 10,
      'checkInLateWarningMinutes': 10,
    });

    expect(policy.checkInReminderLeadMinutes, 10);
    expect(policy.checkInLateWarningMinutes, 10);
    expect(policy.toMap()['checkInReminderLeadMinutes'], 10);
  });

  test('late permission uses the shifted effective start time', () {
    final policy = AttendancePolicyConfig.fromMap({
      'graceMinutes': 15,
      'quarterDayUntilMinutes': 30,
      'halfDayUntilMinutes': 60,
    });
    final arrival = DateTime(2026, 7, 14, 11, 16);

    final result = policy.evaluateLateArrival(
      arrivalTime: arrival,
      employeeStartTime: '11:00',
    );

    expect(result.dayFraction, 0.25);
    expect(result.code, 'quarter_day');
  });
}
