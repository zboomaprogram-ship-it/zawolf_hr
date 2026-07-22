import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_policy.dart';
import 'package:zawolf_hr/services/required_attendance_alarm_service.dart';

void main() {
  test('policy config keeps configurable reminder thresholds', () {
    final policy = AttendancePolicyConfig.fromMap({
      'defaultStartTime': '09:00',
      'checkInReminderLeadMinutes': 10,
      'checkInLateWarningMinutes': 10,
      'checkInFinalWarningLeadMinutes': 5,
    });

    expect(policy.checkInReminderLeadMinutes, 10);
    expect(policy.checkInLateWarningMinutes, 10);
    expect(policy.checkInFinalWarningLeadMinutes, 5);
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

  test('approved two-hour permission keeps 11:20 inside grace period', () {
    final policy = AttendancePolicyConfig.fromMap({
      'graceMinutes': 20,
      'quarterDayUntilMinutes': 30,
      'halfDayUntilMinutes': 60,
    });

    final atGraceBoundary = policy.evaluateLateArrival(
      arrivalTime: DateTime(2026, 7, 22, 11, 20),
      employeeStartTime: '11:00',
    );
    final afterGraceBoundary = policy.evaluateLateArrival(
      arrivalTime: DateTime(2026, 7, 22, 11, 21),
      employeeStartTime: '11:00',
    );

    expect(atGraceBoundary.dayFraction, 0);
    expect(atGraceBoundary.code, 'none');
    expect(afterGraceBoundary.dayFraction, 0.25);
    expect(afterGraceBoundary.code, 'quarter_day');
  });

  test('attendance alarm skips an approved leave date', () {
    final alarms = AttendanceAlarmPlanner.build(
      now: DateTime(2026, 7, 18, 8),
      startTime: '09:00',
      workDays: const [1, 2, 3, 4, 5, 6, 7],
      approvedLeaves: [
        AttendanceAlarmLeaveRange(
          start: DateTime(2026, 7, 18),
          end: DateTime(2026, 7, 18),
        ),
      ],
      companyDaysOff: const {},
      latePermissionMinutes: const {},
      horizonDays: 1,
    );

    expect(alarms, hasLength(1));
    expect(alarms.single.key, '2026-07-19');
  });

  test('attendance alarm follows an approved late permission duration', () {
    final alarms = AttendanceAlarmPlanner.build(
      now: DateTime(2026, 7, 18, 8),
      startTime: '09:00',
      workDays: const [1, 2, 3, 4, 5, 6, 7],
      approvedLeaves: const [],
      companyDaysOff: const {},
      latePermissionMinutes: const {'2026-07-18': 120},
      horizonDays: 0,
    );

    expect(alarms.single.triggerAt, DateTime(2026, 7, 18, 11));
  });
}
