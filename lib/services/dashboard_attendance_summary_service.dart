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

class DashboardAttendancePerson {
  final UserModel employee;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int lateMinutes;

  const DashboardAttendancePerson({
    required this.employee,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.lateMinutes = 0,
  });

  bool get needsCheckout =>
      (status == 'present' || status == 'late') &&
      checkInTime != null &&
      checkOutTime == null;
}

class DashboardAttendanceDayDetails {
  final DashboardAttendanceSummary summary;
  final List<DashboardAttendancePerson> people;

  const DashboardAttendanceDayDetails({
    required this.summary,
    required this.people,
  });
}

class DashboardAttendanceSummaryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DashboardAttendanceSummary> loadForReviewer(UserModel reviewer) async {
    final today = DateTime.now();
    return loadForReviewerDate(reviewer, today);
  }

  Future<List<DashboardAttendanceSummary>> loadLast30DaysForReviewer(
    UserModel reviewer,
  ) async {
    final today = DateTime.now();
    final dates = List.generate(
      30,
      (index) => DateTime(today.year, today.month, today.day - index),
    );
    final employees = await _loadEmployees(reviewer);
    // The previous implementation loaded all 30 days one after another. On a
    // real company account that made this page wait for a long Firestore chain.
    // Keep a small concurrency limit so the page is responsive without sending
    // hundreds of requests at the device/network at once.
    final summaries = <DashboardAttendanceSummary>[];
    const batchSize = 3;
    for (var offset = 0; offset < dates.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, dates.length);
      final batch = await Future.wait(
        dates
            .sublist(offset, end)
            .map((date) => _buildSummaryForDate(reviewer, employees, date)),
      );
      summaries.addAll(batch);
    }
    return summaries;
  }

  Future<DashboardAttendanceSummary> loadForReviewerDate(
    UserModel reviewer,
    DateTime date,
  ) async {
    final employees = await _loadEmployees(reviewer);
    return _buildSummaryForDate(reviewer, employees, date);
  }

  Future<DashboardAttendanceSummary> _buildSummaryForDate(
    UserModel reviewer,
    List<UserModel> employees,
    DateTime date,
  ) async {
    return (await _loadDayDetailsForEmployees(
      reviewer,
      employees,
      date,
    )).summary;
  }

  Future<DashboardAttendanceDayDetails> loadDayDetails(
    UserModel reviewer,
    DateTime date,
  ) async {
    final employees = await _loadEmployees(reviewer);
    return _loadDayDetailsForEmployees(reviewer, employees, date);
  }

  bool _hasTeamScope(UserModel reviewer) {
    return reviewer.role == EmployeeRole.manager ||
        reviewer.role == EmployeeRole.teamLeader;
  }

  Future<DashboardAttendanceDayDetails> _loadDayDetailsForEmployees(
    UserModel reviewer,
    List<UserModel> employees,
    DateTime date,
  ) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final isTeamScope = _hasTeamScope(reviewer);

    if (employees.isEmpty) {
      return DashboardAttendanceDayDetails(
        summary: DashboardAttendanceSummary(
          totalEmployees: 0,
          present: 0,
          late: 0,
          permission: 0,
          dayOff: 0,
          notAttended: 0,
          date: date,
          teamScoped: isTeamScope,
        ),
        people: const [],
      );
    }

    final employeeIds = employees.map((employee) => employee.uid).toSet();
    final results = isTeamScope
        ? await _loadManagerScopedDayData(employeeIds, dateKey, date)
        : await _loadHrScopedDayData(dateKey, date);

    final attendanceByUser = <String, Map<String, dynamic>>{};
    for (final doc in results[0].docs) {
      final data = doc.data();
      if (data == null) continue;
      final userId = data['userId'] as String? ?? '';
      if (employeeIds.contains(userId)) attendanceByUser[userId] = data;
    }

    final permissionUsers = <String>{};
    for (final doc in results[1].docs) {
      final data = doc.data();
      if (data == null) continue;
      final userId = data['userId'] as String? ?? '';
      if (employeeIds.contains(userId)) permissionUsers.add(userId);
    }

    final dayOffUsers = <String>{};
    final startOfToday = DateTime(date.year, date.month, date.day);
    for (final doc in results[2].docs) {
      final data = doc.data();
      if (data == null) continue;
      final userId = data['userId'] as String? ?? '';
      if (!employeeIds.contains(userId)) continue;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      if (endDate == null) continue;
      if (endDate.add(const Duration(days: 1)).isAfter(startOfToday)) {
        dayOffUsers.add(userId);
      }
    }

    final people = <DashboardAttendancePerson>[];

    for (final employee in employees) {
      final attendance = attendanceByUser[employee.uid];
      var status = 'not_attended';
      DateTime? checkInTime;
      DateTime? checkOutTime;
      var lateMinutes = 0;
      if (attendance != null) {
        final hasRealCheckIn = attendance['checkInTime'] != null;
        final attendanceStatus = attendance['status'] as String? ?? 'present';
        final isLate = attendance['isLate'] as bool? ?? false;
        checkInTime = (attendance['checkInTime'] as Timestamp?)?.toDate();
        checkOutTime = (attendance['checkOutTime'] as Timestamp?)?.toDate();
        lateMinutes = (attendance['lateMinutes'] as num?)?.toInt() ?? 0;
        if (attendanceStatus == 'on-leave') {
          status = 'day_off';
        } else if (attendanceStatus == 'absent' || !hasRealCheckIn) {
          status = 'not_attended';
        } else if (isLate || _isLateStatus(attendanceStatus)) {
          status = 'late';
        } else {
          status = 'present';
        }
      } else if (permissionUsers.contains(employee.uid)) {
        status = 'permission';
      } else if (dayOffUsers.contains(employee.uid)) {
        status = 'day_off';
      }
      people.add(
        DashboardAttendancePerson(
          employee: employee,
          status: status,
          checkInTime: checkInTime,
          checkOutTime: checkOutTime,
          lateMinutes: lateMinutes,
        ),
      );
    }

    int count(String status) =>
        people.where((person) => person.status == status).length;
    return DashboardAttendanceDayDetails(
      summary: DashboardAttendanceSummary(
        totalEmployees: employees.length,
        present: count('present'),
        late: count('late'),
        permission: count('permission'),
        dayOff: count('day_off'),
        notAttended: count('not_attended'),
        date: date,
        teamScoped: isTeamScope,
      ),
      people: people,
    );
  }

  Future<List<UserModel>> _loadEmployees(UserModel reviewer) async {
    if (reviewer.role == EmployeeRole.teamLeader) {
      final result = await _safeQueryResult(
        _db.collection('users').where('teamLeaderId', isEqualTo: reviewer.uid),
      );
      return result.docs
          .map(UserModel.fromFirestore)
          .where((employee) => employee.isActive)
          .toList();
    }

    if (reviewer.role == EmployeeRole.manager) {
      final results = await Future.wait([
        _safeQueryResult(
          _db
              .collection('users')
              .where('managerIds', arrayContains: reviewer.uid),
        ),
        _safeQueryResult(
          _db.collection('users').where('managerId', isEqualTo: reviewer.uid),
        ),
      ]);
      final byId = <String, UserModel>{};
      for (final doc in results.expand((result) => result.docs)) {
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

  Future<List<_SummaryQueryResult>> _loadManagerScopedDayData(
    Set<String> employeeIds,
    String dateKey,
    DateTime date,
  ) async {
    final attendanceDocs = await Future.wait(
      employeeIds.map(
        (userId) => _safeDocumentGet(
          _db.collection('attendance').doc('${userId}_$dateKey'),
        ),
      ),
    );
    final permissionSnaps = await Future.wait(
      employeeIds.map(
        (userId) => _safeQueryResult(
          _db
              .collection('permissions')
              .where('userId', isEqualTo: userId)
              .where('requestDate', isEqualTo: dateKey)
              .where('status', isEqualTo: 'approved'),
        ),
      ),
    );
    final leaveSnaps = await Future.wait(
      employeeIds.map(
        (userId) => _safeQueryResult(
          _db
              .collection('leaves')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'approved')
              .where(
                'startDate',
                isLessThanOrEqualTo: Timestamp.fromDate(
                  DateTime(date.year, date.month, date.day, 23, 59, 59),
                ),
              ),
        ),
      ),
    );

    return [
      _SummaryQueryResult(
        attendanceDocs
            .whereType<DocumentSnapshot<Map<String, dynamic>>>()
            .where((doc) => doc.exists)
            .toList(),
      ),
      _SummaryQueryResult(
        permissionSnaps.expand((snapshot) => snapshot.docs).toList(),
      ),
      _SummaryQueryResult(
        leaveSnaps.expand((snapshot) => snapshot.docs).toList(),
      ),
    ];
  }

  Future<List<_SummaryQueryResult>> _loadHrScopedDayData(
    String dateKey,
    DateTime date,
  ) async {
    final results = await Future.wait([
      _safeQueryResult(
        _db.collection('attendance').where('date', isEqualTo: dateKey),
      ),
      _safeQueryResult(
        _db
            .collection('permissions')
            .where('requestDate', isEqualTo: dateKey)
            .where('status', isEqualTo: 'approved'),
      ),
      _safeQueryResult(
        _db
            .collection('leaves')
            .where('status', isEqualTo: 'approved')
            .where(
              'startDate',
              isLessThanOrEqualTo: Timestamp.fromDate(
                DateTime(date.year, date.month, date.day, 23, 59, 59),
              ),
            ),
      ),
    ]);
    return results;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeDocumentGet(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      return await reference.get();
    } on FirebaseException {
      return null;
    }
  }

  Future<_SummaryQueryResult> _safeQueryResult(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return _SummaryQueryResult.fromQuery(await query.get());
    } on FirebaseException {
      return const _SummaryQueryResult([]);
    }
  }

  bool _isLateStatus(String status) {
    return status == 'late' ||
        status == 'late_quarter_day' ||
        status == 'late_half_day' ||
        status == 'late_full_day';
  }
}

class _SummaryQueryResult {
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;

  const _SummaryQueryResult(this.docs);

  factory _SummaryQueryResult.fromQuery(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _SummaryQueryResult(snapshot.docs);
  }
}
