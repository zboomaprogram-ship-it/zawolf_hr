import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/employee_role.dart';
import '../models/user_model.dart';

class DashboardAttendanceSummary {
  final int totalEmployees;
  final int present;
  final int late;
  final int permission;
  final int dayOff;
  final int notAttended;
  final DateTime date;
  final bool teamScoped;

  const DashboardAttendanceSummary({
    required this.totalEmployees,
    required this.present,
    required this.late,
    required this.permission,
    required this.dayOff,
    required this.notAttended,
    required this.date,
    required this.teamScoped,
  });

  int get accounted => present + late + permission + dayOff + notAttended;

  double percentOf(int value) {
    if (totalEmployees == 0) return 0;
    return (value / totalEmployees) * 100;
  }
}

class DashboardAttendanceSummaryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DashboardAttendanceSummary> loadForReviewer(UserModel reviewer) async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final isManagerScope = reviewer.role == EmployeeRole.manager;

    final employees = await _loadEmployees(reviewer, isManagerScope);
    if (employees.isEmpty) {
      return DashboardAttendanceSummary(
        totalEmployees: 0,
        present: 0,
        late: 0,
        permission: 0,
        dayOff: 0,
        notAttended: 0,
        date: today,
        teamScoped: isManagerScope,
      );
    }

    final employeeIds = employees.map((employee) => employee.uid).toSet();
    final results = await Future.wait([
      _db.collection('attendance').where('date', isEqualTo: todayKey).get(),
      _db
          .collection('permissions')
          .where('requestDate', isEqualTo: todayKey)
          .where('status', isEqualTo: 'approved')
          .get(),
      _db
          .collection('leaves')
          .where('status', isEqualTo: 'approved')
          .where(
            'startDate',
            isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime(today.year, today.month, today.day, 23, 59, 59),
            ),
          )
          .get(),
    ]);

    final attendanceByUser = <String, Map<String, dynamic>>{};
    for (final doc in results[0].docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      if (employeeIds.contains(userId)) attendanceByUser[userId] = data;
    }

    final permissionUsers = <String>{};
    for (final doc in results[1].docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      if (employeeIds.contains(userId)) permissionUsers.add(userId);
    }

    final dayOffUsers = <String>{};
    final startOfToday = DateTime(today.year, today.month, today.day);
    for (final doc in results[2].docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      if (!employeeIds.contains(userId)) continue;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      if (endDate == null) continue;
      if (endDate.add(const Duration(days: 1)).isAfter(startOfToday)) {
        dayOffUsers.add(userId);
      }
    }

    var present = 0;
    var late = 0;
    var permission = 0;
    var dayOff = 0;
    var notAttended = 0;

    for (final employee in employees) {
      final attendance = attendanceByUser[employee.uid];
      if (attendance != null) {
        final status = attendance['status'] as String? ?? 'present';
        final isLate = attendance['isLate'] as bool? ?? false;
        if (isLate || _isLateStatus(status)) {
          late++;
        } else {
          present++;
        }
      } else if (permissionUsers.contains(employee.uid)) {
        permission++;
      } else if (dayOffUsers.contains(employee.uid)) {
        dayOff++;
      } else {
        notAttended++;
      }
    }

    return DashboardAttendanceSummary(
      totalEmployees: employees.length,
      present: present,
      late: late,
      permission: permission,
      dayOff: dayOff,
      notAttended: notAttended,
      date: today,
      teamScoped: isManagerScope,
    );
  }

  Future<List<UserModel>> _loadEmployees(
    UserModel reviewer,
    bool managerScope,
  ) async {
    if (managerScope) {
      final modernSnap = await _db
          .collection('users')
          .where('managerIds', arrayContains: reviewer.uid)
          .get();
      final legacySnap = await _db
          .collection('users')
          .where('managerId', isEqualTo: reviewer.uid)
          .get();
      final byId = <String, UserModel>{};
      for (final doc in [...modernSnap.docs, ...legacySnap.docs]) {
        final employee = UserModel.fromFirestore(doc);
        if (employee.isActive &&
            employee.role != EmployeeRole.superAdmin &&
            (employee.managerIds.contains(reviewer.uid) ||
                employee.managerId == reviewer.uid)) {
          byId[employee.uid] = employee;
        }
      }
      return byId.values.toList();
    }

    final snap = await _db
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map(UserModel.fromFirestore).where((employee) {
      if (employee.role == EmployeeRole.superAdmin) return false;
      return true;
    }).toList();
  }

  bool _isLateStatus(String status) {
    return status == 'late' ||
        status == 'late_quarter_day' ||
        status == 'late_half_day' ||
        status == 'late_full_day';
  }
}
