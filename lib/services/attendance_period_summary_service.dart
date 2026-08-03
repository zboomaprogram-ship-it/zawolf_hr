import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/user_model.dart';

class AttendancePeriodDay {
  final DateTime date;
  final String dateKey;
  final AttendanceModel? attendance;
  final bool isExpectedWorkDay;
  final bool isApprovedLeave;

  const AttendancePeriodDay({
    required this.date,
    required this.dateKey,
    required this.attendance,
    required this.isExpectedWorkDay,
    required this.isApprovedLeave,
  });

  bool get isAbsent =>
      isExpectedWorkDay &&
      !isApprovedLeave &&
      (attendance == null || attendance!.status == 'absent');

  bool get isPresent =>
      attendance?.checkInTime != null && attendance?.status != 'absent';

  bool get isLate =>
      isPresent &&
      (attendance!.isLate ||
          attendance!.status == 'late' ||
          attendance!.status.startsWith('late_'));
}

class AttendancePeriodSummary {
  final List<AttendancePeriodDay> days;

  const AttendancePeriodSummary(this.days);

  int get expectedDays => days.where((day) => day.isExpectedWorkDay).length;
  int get presentDays => days.where((day) => day.isPresent).length;
  int get lateDays => days.where((day) => day.isLate).length;
  int get absentDays => days.where((day) => day.isAbsent).length;
}

class AttendancePeriodSummaryService {
  final FirebaseFirestore _db;

  AttendancePeriodSummaryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<AttendancePeriodSummary> loadForUser({
    required UserModel user,
    required DateTime start,
    required DateTime end,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final startDay = DateTime(start.year, start.month, start.day);
    final requestedEnd = DateTime(end.year, end.month, end.day);
    final today = DateTime(current.year, current.month, current.day);
    final effectiveEnd = requestedEnd.isAfter(today) ? today : requestedEnd;
    if (effectiveEnd.isBefore(startDay)) {
      return const AttendancePeriodSummary([]);
    }

    final startKey = DateFormat('yyyy-MM-dd').format(startDay);
    final endExclusive = effectiveEnd.add(const Duration(days: 1));
    final endExclusiveKey = DateFormat('yyyy-MM-dd').format(endExclusive);

    final snapshots = await Future.wait([
      _db
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThan: endExclusiveKey)
          .get(),
      _db.collection('leaves').where('userId', isEqualTo: user.uid).get(),
      _db.collection('companyDayOffs').get(),
    ]);

    final attendanceByDate = <String, AttendanceModel>{};
    for (final doc in snapshots[0].docs) {
      final item = AttendanceModel.fromFirestore(doc);
      attendanceByDate[item.date] = item;
    }
    final approvedLeaves = snapshots[1].docs
        .map(LeaveModel.fromFirestore)
        .where((leave) => leave.status == 'approved')
        .toList();
    final companyDaysOff = snapshots[2].docs
        .where((doc) => doc.data()['isActive'] == true)
        .map((doc) => doc.data()['date'] as String? ?? doc.id)
        .toSet();

    return buildSummary(
      user: user,
      start: startDay,
      end: effectiveEnd,
      now: current,
      attendanceByDate: attendanceByDate,
      approvedLeaves: approvedLeaves,
      companyDaysOff: companyDaysOff,
    );
  }

  static AttendancePeriodSummary buildSummary({
    required UserModel user,
    required DateTime start,
    required DateTime end,
    required DateTime now,
    required Map<String, AttendanceModel> attendanceByDate,
    required List<LeaveModel> approvedLeaves,
    required Set<String> companyDaysOff,
  }) {
    const defaultWorkDays = [6, 7, 1, 2, 3, 4];
    final workDays = user.workSchedule.workDays?.isNotEmpty == true
        ? user.workSchedule.workDays!
        : defaultWorkDays;
    final joinDay = user.joinDate == null
        ? null
        : DateTime(
            user.joinDate!.year,
            user.joinDate!.month,
            user.joinDate!.day,
          );
    final today = DateTime(now.year, now.month, now.day);
    final endParts = (user.workSchedule.endTime ?? '17:00').split(':');
    final shiftEndHour = int.tryParse(endParts.first) ?? 17;
    final shiftEndMinute = endParts.length > 1
        ? int.tryParse(endParts[1]) ?? 0
        : 0;
    final result = <AttendancePeriodDay>[];

    for (
      var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      final attendance = attendanceByDate[key];
      final onApprovedLeave = approvedLeaves.any(
        (leave) =>
            !day.isBefore(_dateOnly(leave.startDate)) &&
            !day.isAfter(_dateOnly(leave.endDate)),
      );
      final scheduled = workDays.contains(day.weekday);
      final joined = joinDay == null || !day.isBefore(joinDay);
      final companyDayOff = companyDaysOff.contains(key);
      final shiftFinishedToday = day == today
          ? now.isAfter(
              DateTime(
                day.year,
                day.month,
                day.day,
                shiftEndHour,
                shiftEndMinute,
              ),
            )
          : day.isBefore(today);
      final expected =
          scheduled &&
          joined &&
          !companyDayOff &&
          !onApprovedLeave &&
          (shiftFinishedToday || attendance?.checkInTime != null);

      result.add(
        AttendancePeriodDay(
          date: day,
          dateKey: key,
          attendance: attendance,
          isExpectedWorkDay: expected,
          isApprovedLeave: onApprovedLeave,
        ),
      );
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return AttendancePeriodSummary(result);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
