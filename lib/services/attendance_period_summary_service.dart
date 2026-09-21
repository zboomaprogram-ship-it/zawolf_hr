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
  final bool isApprovedPermission;

  const AttendancePeriodDay({
    required this.date,
    required this.dateKey,
    required this.attendance,
    required this.isExpectedWorkDay,
    required this.isApprovedLeave,
    this.isApprovedPermission = false,
  });

  bool get isAbsent =>
      isExpectedWorkDay &&
      !isApprovedLeave &&
      !isApprovedPermission &&
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
  final double approvedPermissionConsequenceFractions;

  const AttendancePeriodSummary(
    this.days, {
    this.approvedPermissionConsequenceFractions = 0,
  });

  int get expectedDays => days.where((day) => day.isExpectedWorkDay).length;
  int get presentDays => days.where((day) => day.isPresent).length;
  int get lateDays => days.where((day) => day.isLate).length;
  int get absentDays => days.where((day) => day.isAbsent).length;

  /// Discipline reflects active attendance infractions (unexplained absences,
  /// late arrivals, missed checkouts) and approved consequence fractions.
  /// Deductions that HR has explicitly rejected or reversed do not lower the score.
  double get disciplineImpactDayFractions =>
      approvedPermissionConsequenceFractions +
      days.fold<double>(0, (total, day) {
        if (day.isAbsent) {
          final attendance = day.attendance;
          if (attendance != null &&
              (attendance.salaryDeductionApprovalStatus == 'rejected' ||
                  attendance.salaryDeductionApprovalStatus == 'reversed')) {
            return total;
          }
          final fraction = attendance?.salaryDeductionFraction;
          return total + (fraction != null && fraction > 0 ? fraction : 1.0);
        }
        final attendance = day.attendance;
        if (attendance == null ||
            attendance.salaryDeductionApprovalStatus == 'rejected' ||
            attendance.salaryDeductionApprovalStatus == 'reversed' ||
            attendance.salaryDeductionFraction <= 0) {
          return total;
        }
        return total + attendance.salaryDeductionFraction;
      });

  /// Employee dashboard discipline percentage for the selected period.
  ///
  /// Active and pending deductions are reflected in the dashboard score, while
  /// payroll still waits for HR approval before deducting salary.
  double get disciplinePercentage {
    if (expectedDays == 0) return 100;
    final score = 100 * (1 - (disciplineImpactDayFractions / expectedDays));
    return score.clamp(0, 100).toDouble();
  }
}

class AttendancePeriodSummaryService {
  final FirebaseFirestore _db;

  AttendancePeriodSummaryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeAttendanceQuery(
    String uid,
    String startKey,
    String endExclusiveKey,
  ) async {
    try {
      final snap = await _db
          .collection('attendance')
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThan: endExclusiveKey)
          .get();
      return snap.docs;
    } catch (_) {
      final snap = await _db
          .collection('attendance')
          .where('userId', isEqualTo: uid)
          .get();
      return snap.docs;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeLeavesQuery(
    String uid,
    Timestamp endExclusive,
  ) async {
    try {
      final snap = await _db
          .collection('leaves')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'approved')
          .where('startDate', isLessThan: endExclusive)
          .get();
      return snap.docs;
    } catch (_) {
      final snap = await _db
          .collection('leaves')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'approved')
          .get();
      return snap.docs;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safePermissionsQuery(
    String uid,
    String startKey,
    String endExclusiveKey,
  ) async {
    try {
      final snap = await _db
          .collection('permissions')
          .where('userId', isEqualTo: uid)
          .where('requestDate', isGreaterThanOrEqualTo: startKey)
          .where('requestDate', isLessThan: endExclusiveKey)
          .get();
      return snap.docs;
    } catch (_) {
      final snap = await _db
          .collection('permissions')
          .where('userId', isEqualTo: uid)
          .get();
      return snap.docs;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeCompanyDayOffsQuery() async {
    try {
      final snap = await _db.collection('companyDayOffs').get();
      return snap.docs;
    } catch (_) {
      return const [];
    }
  }

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

    final results = await Future.wait([
      _safeAttendanceQuery(user.uid, startKey, endExclusiveKey),
      _safeLeavesQuery(user.uid, Timestamp.fromDate(endExclusive)),
      _safePermissionsQuery(user.uid, startKey, endExclusiveKey),
      _safeCompanyDayOffsQuery(),
    ]);

    final attendanceByDate = <String, AttendanceModel>{};
    for (final doc in results[0]) {
      final item = AttendanceModel.fromFirestore(doc);
      if (item.date.compareTo(startKey) >= 0 &&
          item.date.compareTo(endExclusiveKey) < 0) {
        attendanceByDate[item.date] = item;
      }
    }
    final approvedLeaves =
        results[1]
            .map(LeaveModel.fromFirestore)
            .where((leave) => !leave.endDate.isBefore(startDay))
            .toList();
    final approvedPermissionDates =
        results[2]
            .where((doc) => doc.data()['status'] == 'approved')
            .map((doc) => doc.data()['requestDate'] as String? ?? '')
            .where(
              (date) =>
                  date.isNotEmpty &&
                  date.compareTo(startKey) >= 0 &&
                  date.compareTo(endExclusiveKey) < 0,
            )
            .toSet();
    final companyDaysOff =
        results[3]
            .where((doc) => doc.data()['isActive'] == true)
            .map((doc) => doc.data()['date'] as String? ?? doc.id)
            .toSet();

    final approvedPermissionConsequenceFractions = results[2]
        .where((doc) {
          final date = doc.data()['requestDate'] as String? ?? '';
          return date.compareTo(startKey) >= 0 &&
              date.compareTo(endExclusiveKey) < 0;
        })
        .fold<double>(0, (total, doc) {
          final consequence = doc.data()['rejectionConsequence'];
          if (consequence is! Map || consequence['status'] != 'approved') {
            return total;
          }
          return total +
              ((consequence['dayFraction'] as num?)?.toDouble() ?? 0);
        });
    final summary = buildSummary(
      user: user,
      start: startDay,
      end: effectiveEnd,
      now: current,
      attendanceByDate: attendanceByDate,
      approvedLeaves: approvedLeaves,
      approvedPermissionDates: approvedPermissionDates,
      companyDaysOff: companyDaysOff,
    );
    return AttendancePeriodSummary(
      summary.days,
      approvedPermissionConsequenceFractions:
          approvedPermissionConsequenceFractions,
    );
  }

  static AttendancePeriodSummary buildSummary({
    required UserModel user,
    required DateTime start,
    required DateTime end,
    required DateTime now,
    required Map<String, AttendanceModel> attendanceByDate,
    required List<LeaveModel> approvedLeaves,
    Set<String> approvedPermissionDates = const {},
    required Set<String> companyDaysOff,
  }) {
    const defaultWorkDays = [6, 7, 1, 2, 3, 4];
    final workDays =
        user.workSchedule.workDays?.isNotEmpty == true
            ? user.workSchedule.workDays!
            : defaultWorkDays;
    final joinDay =
        user.joinDate == null
            ? null
            : DateTime(
              user.joinDate!.year,
              user.joinDate!.month,
              user.joinDate!.day,
            );
    final today = DateTime(now.year, now.month, now.day);
    final endParts = (user.workSchedule.endTime ?? '17:00').split(':');
    final shiftEndHour = int.tryParse(endParts.first) ?? 17;
    final shiftEndMinute =
        endParts.length > 1 ? int.tryParse(endParts[1]) ?? 0 : 0;
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
      final onApprovedPermission = approvedPermissionDates.contains(key);
      final scheduled = workDays.contains(day.weekday);
      final joined = joinDay == null || !day.isBefore(joinDay);
      final companyDayOff = companyDaysOff.contains(key);
      final shiftFinishedToday =
          day == today
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
          isApprovedPermission: onApprovedPermission,
        ),
      );
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return AttendancePeriodSummary(result);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
