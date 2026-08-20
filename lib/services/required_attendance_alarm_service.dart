import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_policy.dart';
import '../models/user_model.dart';
import 'personal_alarm_service.dart';

class AttendanceAlarmLeaveRange {
  final DateTime start;
  final DateTime end;

  const AttendanceAlarmLeaveRange({required this.start, required this.end});

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    return !day.isBefore(first) && !day.isAfter(last);
  }
}

class AttendanceAlarmPlanner {
  const AttendanceAlarmPlanner._();

  static List<DatedAttendanceAlarm> build({
    required DateTime now,
    required String startTime,
    required List<int> workDays,
    required List<AttendanceAlarmLeaveRange> approvedLeaves,
    required Set<String> companyDaysOff,
    required Map<String, int> latePermissionMinutes,
    int horizonDays = 30,
  }) {
    final alarms = <DatedAttendanceAlarm>[];
    for (var offset = 0; offset <= horizonDays; offset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));
      final dateKey = _dateKey(date);
      if (!workDays.contains(date.weekday) ||
          companyDaysOff.contains(dateKey) ||
          approvedLeaves.any((leave) => leave.contains(date))) {
        continue;
      }

      final base = AttendancePolicy.parseTimeOnDate(date, startTime);
      final triggerAt = base.add(
        Duration(minutes: latePermissionMinutes[dateKey] ?? 0),
      );
      if (!triggerAt.isAfter(now)) continue;
      alarms.add(
        DatedAttendanceAlarm(
          key: dateKey,
          triggerAt: triggerAt,
          message: 'حان وقت تسجيل الحضور في ZaWolf HR',
        ),
      );
    }
    return alarms;
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Keeps the optional attendance alarm aligned with approved HR data.
class RequiredAttendanceAlarmService {
  RequiredAttendanceAlarmService._();
  static final RequiredAttendanceAlarmService instance =
      RequiredAttendanceAlarmService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String alarmUserId(String userId) => 'required_attendance_$userId';

  String _promptedKey(String userId) =>
      'attendance_alarm_permission_prompted_$userId';

  Future<bool> hasPrompted(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_promptedKey(userId)) ?? false;
  }

  Future<void> markPrompted(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_promptedKey(userId), true);
  }

  String startTimeFor(UserModel user) =>
      user.workSchedule.startTime ?? AttendancePolicy.defaultStartTime;

  Future<PersonalAlarmSettings> load(String userId) {
    return PersonalAlarmService.instance.load(alarmUserId(userId));
  }

  Future<PersonalAlarmSettings> enableFor(UserModel user) async {
    final ownerId = alarmUserId(user.uid);
    final today = DateTime.now();
    final horizon = DateTime(
      today.year,
      today.month,
      today.day + 30,
      23,
      59,
      59,
    );
    String dateKey(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final snapshots = await Future.wait([
      _db
          .collection('leaves')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'approved')
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(horizon))
          .get(),
      _db
          .collection('permissions')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'approved')
          .where('requestDate', isGreaterThanOrEqualTo: dateKey(today))
          .where('requestDate', isLessThanOrEqualTo: dateKey(horizon))
          .get(),
      _db.collection('companyDayOffs').where('isActive', isEqualTo: true).get(),
    ]);

    final approvedLeaves = snapshots[0].docs
        .where((doc) => doc.data()['status'] == 'approved')
        .map((doc) {
          final data = doc.data();
          final start = data['startDate'];
          final end = data['endDate'];
          if (start is! Timestamp || end is! Timestamp) return null;
          return AttendanceAlarmLeaveRange(
            start: start.toDate(),
            end: end.toDate(),
          );
        })
        .whereType<AttendanceAlarmLeaveRange>()
        .toList();

    final latePermissions = <String, int>{};
    for (final doc in snapshots[1].docs) {
      final data = doc.data();
      if (data['status'] != 'approved' ||
          data['permissionType'] != 'late_arrival') {
        continue;
      }
      final date = data['requestDate'] as String? ?? '';
      final minutes = (data['durationMinutes'] as num?)?.toInt() ?? 0;
      if (date.isNotEmpty && minutes > (latePermissions[date] ?? 0)) {
        latePermissions[date] = minutes;
      }
    }

    final companyDaysOff = snapshots[2].docs
        .where((doc) => doc.data()['isActive'] == true)
        .map((doc) => doc.data()['date'] as String? ?? doc.id)
        .toSet();
    final startTime = startTimeFor(user);
    final alarms = AttendanceAlarmPlanner.build(
      now: DateTime.now(),
      startTime: startTime,
      workDays:
          user.workSchedule.workDays ??
          AttendancePolicy.saturdayToThursdayWorkDays,
      approvedLeaves: approvedLeaves,
      companyDaysOff: companyDaysOff,
      latePermissionMinutes: latePermissions,
    );

    // Remove the old weekly alarm before installing the date-aware schedule.
    await PersonalAlarmService.instance.disable(ownerId);
    await PersonalAlarmService.instance.replaceDatedAttendanceSchedule(
      ownerId: ownerId,
      alarms: alarms,
    );
    final time = _parseTime(startTime);
    return PersonalAlarmSettings(enabled: true, hour: time.$1, minute: time.$2);
  }

  Future<bool> syncIfEnabled(UserModel user) async {
    final settings = await load(user.uid);
    if (!settings.enabled) return false;
    await enableFor(user);
    startWatching(user);
    return true;
  }

  void startWatching(UserModel _) {
    // The 30-day schedule is refreshed when the authenticated shell starts.
    // Persistent collection listeners previously read the same history again
    // and each initial snapshot triggered three more full queries.
  }

  void stopWatching() {}

  Future<void> disable(String userId) async {
    stopWatching();
    final ownerId = alarmUserId(userId);
    await PersonalAlarmService.instance.disable(ownerId);
    await PersonalAlarmService.instance.disableDatedAttendanceSchedule(ownerId);
  }

  (int, int) _parseTime(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return (
      (hour ?? 9).clamp(0, 23).toInt(),
      (minute ?? 0).clamp(0, 59).toInt(),
    );
  }
}
