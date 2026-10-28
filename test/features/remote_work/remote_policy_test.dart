import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_policy.dart';

void main() {
  test('attendance policy round-trips dynamic remote policy settings', () {
    final source = <String, dynamic>{
      'defaultStartTime': '08:30',
      'remoteWorkPolicy': {
        'schemaVersion': 1,
        'enabled': false,
        'eligibility': {
          'weekStartDay': 6,
          'allowedWeekdays': [6, 1, 3],
          'daysPerWeek': 2,
          'probationEligible': true,
        },
        'schedule': {
          'startTime': {'mode': 'inherit'},
          'endTime': {'mode': 'override', 'value': '19:30'},
          'checkpoints': [
            {'id': 'focus', 'label': 'تركيز', 'dueTime': '10:45'},
            {'id': 'wrap-up', 'label': 'إغلاق', 'dueTime': '16:15'},
          ],
        },
        'approvals': {
          'remoteDay': [
            {'id': 'manager', 'resolver': 'manager', 'required': true},
            {'id': 'ceo', 'resolver': 'ceo', 'required': false},
          ],
        },
        'futureExtension': {'customThreshold': 7},
      },
    };

    final policy = AttendancePolicyConfig.fromMap(source);
    final serialized = policy.toMap();
    final restored = AttendancePolicyConfig.fromMap(serialized);

    expect(serialized['defaultStartTime'], '08:30');
    expect(restored.remoteWorkPolicy, source['remoteWorkPolicy']);
  });

  test('legacy attendance policy has no enabled remote policy', () {
    final policy = AttendancePolicyConfig.fromMap({
      'defaultStartTime': '09:00',
    });

    expect(policy.remoteWorkPolicy['enabled'], isNot(true));
  });

  test('older policy editor serialization retains unknown shared policy fields', () {
    final policy = AttendancePolicyConfig.fromMap({
      'defaultStartTime': '08:30',
      'futureAttendanceRestriction': {'mode': 'strict', 'values': [1, 2]},
    });

    expect(
      policy.toMap()['futureAttendanceRestriction'],
      {'mode': 'strict', 'values': [1, 2]},
    );
  });

  test('remote policy accepts zero or many configured checkpoints', () {
    final empty = RemoteWorkPolicyValidation.validate({
      'enabled': true,
      'eligibility': {
        'daysPerWeek': 2,
        'allowedWeekdays': [6, 1],
      },
      'schedule': {'checkpoints': []},
    });
    final many = RemoteWorkPolicyValidation.validate({
      'enabled': true,
      'eligibility': {
        'daysPerWeek': 3,
        'allowedWeekdays': [6, 7, 1, 2],
      },
      'schedule': {
        'checkpoints': [
          {'id': 'one', 'dueTime': '08:45', 'graceMinutes': 0},
          {'id': 'two', 'dueTime': '12:00', 'graceMinutes': 20},
          {'id': 'three', 'dueTime': '16:45', 'graceMinutes': 15},
          {'id': 'four', 'dueTime': '18:00', 'graceMinutes': 30},
          {'id': 'five', 'dueTime': '20:00', 'graceMinutes': 45},
        ],
      },
    });

    expect(empty, isEmpty);
    expect(many, isEmpty);
  });

  test('remote policy rejects allowance and checkpoint definition errors', () {
    final errors = RemoteWorkPolicyValidation.validate({
      'enabled': true,
      'eligibility': {
        'daysPerWeek': 3,
        'allowedWeekdays': [6, 1],
        'weekStartDay': 9,
      },
      'schedule': {
        'endDayOffset': 2,
        'checkpoints': [
          {'id': 'duplicate', 'dueTime': '26:00', 'graceMinutes': -1},
          {'id': 'duplicate', 'dueTime': '10:00', 'graceMinutes': 0},
        ],
      },
    });

    expect(errors, contains('eligibility.daysPerWeek'));
    expect(errors, contains('eligibility.weekStartDay'));
    expect(errors, contains('schedule.endDayOffset'));
    expect(errors, contains('schedule.checkpoints[0].dueTime'));
    expect(errors, contains('schedule.checkpoints[0].graceMinutes'));
    expect(errors, contains('schedule.checkpoints[1].id'));
  });
}
