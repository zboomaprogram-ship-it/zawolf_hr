import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/employee_role.dart';
import '../models/user_model.dart';
import '../utils/payroll_cycle.dart';

class SmartAssistantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> ask(String query, UserModel user) async {
    final normalized = _normalize(query);
    if (!_canUseAssistant(user)) {
      return 'عذراً، المساعد الإداري متاح للمديرين و HR ومالك النظام فقط.';
    }

    if (_containsAny(normalized, ['مساعدة', 'help', 'تقدر تعمل ايه'])) {
      return _helpText(user);
    }
    if (_containsAny(normalized, [
      'ازاي اضيف',
      'اضافة موظفين',
      'موظفين كتير',
      'فريق جديد',
      'marketing',
      'ماركتينج',
      'تست',
    ])) {
      return _teamSetupGuide(user);
    }
    if (_containsAny(normalized, [
      'ملخص',
      'احصائيات',
      'نسبة الحضور',
      'dashboard',
      'داشبورد',
    ])) {
      return _attendanceSummary(user);
    }
    if (_containsAny(normalized, ['مين غايب', 'الغياب', 'لم يسجل'])) {
      return _listByAttendanceState(user, _AttendanceAssistantState.absent);
    }
    if (_containsAny(normalized, ['مين حضر', 'حضور اليوم', 'الحاضرين'])) {
      return _listByAttendanceState(user, _AttendanceAssistantState.present);
    }
    if (_containsAny(normalized, [
      'مين متاخر',
      'مين متأخر',
      'المتاخر',
      'المتأخر',
    ])) {
      return _listByAttendanceState(user, _AttendanceAssistantState.late);
    }
    if (_containsAny(normalized, ['اذن', 'إذن', 'تصريح', 'permission'])) {
      return _todayApprovedPermissions(user);
    }
    if (_containsAny(normalized, [
      'اجازة',
      'إجازة',
      'day off',
      'dayoff',
      'عطلة',
    ])) {
      return _todayApprovedLeaves(user);
    }
    if (_containsAny(normalized, [
      'طلبات معلقة',
      'pending',
      'موافقات',
      'الموافقات',
    ])) {
      return _pendingRequests(user);
    }
    if (_containsAny(normalized, [
      'مهام متاخرة',
      'مهام متأخرة',
      'late tasks',
      'overdue',
    ])) {
      return _overdueTasks(user);
    }
    if (_containsAny(normalized, ['عدد الموظفين', 'الموظفين', 'الفريق'])) {
      return _employeesOverview(user);
    }
    if (_containsAny(normalized, ['راتب', 'رواتب', 'payroll'])) {
      return _payrollOverview(user);
    }

    return _helpText(user);
  }

  bool _canUseAssistant(UserModel user) {
    return user.role == EmployeeRole.manager ||
        user.role == EmployeeRole.hrAdmin ||
        user.role == EmployeeRole.superAdmin;
  }

  String _helpText(UserModel user) {
    final scope = user.role == EmployeeRole.manager
        ? 'سأجيب فقط عن موظفيك المعينين لك.'
        : 'سأجيب عن بيانات الشركة كلها حسب صلاحيتك.';
    return '$scope\n\nاسألني مثلاً:\n'
        '- مين غايب اليوم؟\n'
        '- مين متأخر؟\n'
        '- نسبة الحضور اليوم؟\n'
        '- الطلبات المعلقة؟\n'
        '- المهام المتأخرة؟\n'
        '- عدد الموظفين؟\n'
        '- ازاي أضيف مدير و10 موظفين بسرعة؟';
  }

  Future<String> _attendanceSummary(UserModel user) async {
    final today = _todayKey();
    final employees = await _scopedEmployees(user);
    if (employees.isEmpty) return 'لا يوجد موظفون نشطون في نطاق صلاحيتك.';
    final employeeIds = employees.map((employee) => employee.uid).toSet();
    final attendance = await _todayAttendance(employeeIds, today);
    final permissionUsers = await _todayPermissionUsers(employeeIds, today);
    final leaveUsers = await _todayLeaveUsers(employeeIds);

    var present = 0;
    var late = 0;
    var permission = 0;
    var leave = 0;
    var absent = 0;
    for (final employee in employees) {
      final log = attendance[employee.uid];
      if (log != null) {
        final status = log['status'] as String? ?? 'present';
        final isLate = log['isLate'] as bool? ?? false;
        if (isLate || _isLateStatus(status)) {
          late++;
        } else {
          present++;
        }
      } else if (permissionUsers.contains(employee.uid)) {
        permission++;
      } else if (leaveUsers.contains(employee.uid)) {
        leave++;
      } else {
        absent++;
      }
    }

    String pct(int value) => employees.isEmpty
        ? '0%'
        : '${((value / employees.length) * 100).toStringAsFixed(0)}%';
    return 'ملخص اليوم $today:\n'
        '- حاضر: $present (${pct(present)})\n'
        '- متأخر: $late (${pct(late)})\n'
        '- بإذن: $permission (${pct(permission)})\n'
        '- إجازة/Day off: $leave (${pct(leave)})\n'
        '- لم يسجل حضور: $absent (${pct(absent)})';
  }

  Future<String> _listByAttendanceState(
    UserModel user,
    _AttendanceAssistantState state,
  ) async {
    final today = _todayKey();
    final employees = await _scopedEmployees(user);
    final employeeIds = employees.map((employee) => employee.uid).toSet();
    final attendance = await _todayAttendance(employeeIds, today);
    final permissionUsers = await _todayPermissionUsers(employeeIds, today);
    final leaveUsers = await _todayLeaveUsers(employeeIds);

    final matched = <UserModel>[];
    for (final employee in employees) {
      final log = attendance[employee.uid];
      final status = log?['status'] as String? ?? '';
      final isLate = log?['isLate'] as bool? ?? false;
      final absent =
          log == null &&
          !permissionUsers.contains(employee.uid) &&
          !leaveUsers.contains(employee.uid);

      if (state == _AttendanceAssistantState.present &&
          log != null &&
          !isLate &&
          !_isLateStatus(status)) {
        matched.add(employee);
      } else if (state == _AttendanceAssistantState.late &&
          log != null &&
          (isLate || _isLateStatus(status))) {
        matched.add(employee);
      } else if (state == _AttendanceAssistantState.absent && absent) {
        matched.add(employee);
      }
    }

    if (matched.isEmpty) return 'لا يوجد موظفون مطابقون لهذا السؤال اليوم.';
    return matched
        .map((employee) {
          final manager = employee.managerName == null
              ? ''
              : ' · مديره: ${employee.managerName}';
          return '- ${employee.displayName} (${employee.employeeId}) · ${employee.department}$manager';
        })
        .join('\n');
  }

  Future<String> _todayApprovedPermissions(UserModel user) async {
    final today = _todayKey();
    final ids = (await _scopedEmployees(user)).map((e) => e.uid).toSet();
    final snap = await _db
        .collection('permissions')
        .where('requestDate', isEqualTo: today)
        .where('status', isEqualTo: 'approved')
        .get();
    final rows = snap.docs
        .where((doc) => ids.contains(doc.data()['userId']))
        .toList();
    if (rows.isEmpty) return 'لا توجد أذونات معتمدة اليوم في نطاق صلاحيتك.';
    return rows
        .map((doc) {
          final data = doc.data();
          return '- ${data['employeeName'] ?? ''}: ${data['permissionType'] == 'late_arrival' ? 'تأخير حضور' : 'انصراف مبكر'} · ${data['expectedTime'] ?? ''}';
        })
        .join('\n');
  }

  Future<String> _todayApprovedLeaves(UserModel user) async {
    final ids = (await _scopedEmployees(user)).map((e) => e.uid).toSet();
    final leaveUsers = await _todayLeaveUsers(ids);
    if (leaveUsers.isEmpty) return 'لا توجد إجازات أو Day off معتمدة اليوم.';
    final employees = await _scopedEmployees(user);
    return employees
        .where((employee) => leaveUsers.contains(employee.uid))
        .map((employee) => '- ${employee.displayName} (${employee.employeeId})')
        .join('\n');
  }

  Future<String> _pendingRequests(UserModel user) async {
    final isManager = user.role == EmployeeRole.manager;
    final status = isManager ? 'pending_manager' : 'pending_hr';
    final leaves = await _pendingCount('leaves', user, status);
    final permissions = await _pendingCount('permissions', user, status);
    final advances = await _pendingCount('advances', user, status);
    return 'الطلبات المعلقة الآن:\n'
        '- إجازات/Day off: $leaves\n'
        '- أذونات: $permissions\n'
        '- سلف: $advances';
  }

  Future<String> _overdueTasks(UserModel user) async {
    Query<Map<String, dynamic>> query = _db
        .collection('tasks')
        .where('dueDate', isLessThan: Timestamp.now())
        .where('status', whereIn: ['new', 'in_progress', 'late']);
    if (user.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: user.uid);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return 'لا توجد مهام متأخرة في نطاق صلاحيتك.';
    final preview = snap.docs
        .take(8)
        .map((doc) {
          final data = doc.data();
          return '- ${data['title'] ?? ''} · ${data['assigneeName'] ?? ''}';
        })
        .join('\n');
    return 'عدد المهام المتأخرة: ${snap.docs.length}\n$preview';
  }

  Future<String> _employeesOverview(UserModel user) async {
    final employees = await _scopedEmployees(user);
    final byRole = <String, int>{};
    for (final employee in employees) {
      byRole[employee.role] = (byRole[employee.role] ?? 0) + 1;
    }
    return 'عدد الموظفين النشطين في نطاقك: ${employees.length}\n'
        '- موظفين: ${byRole[EmployeeRole.employee] ?? 0}\n'
        '- مديرين: ${byRole[EmployeeRole.manager] ?? 0}\n'
        '- HR: ${byRole[EmployeeRole.hrAdmin] ?? 0}';
  }

  Future<String> _payrollOverview(UserModel user) async {
    if (user.role == EmployeeRole.manager) {
      return 'المدير لا يرى كشوف رواتب الفريق من المساعد. كشوف الرواتب متاحة لـ HR ومالك النظام فقط.';
    }
    final monthKey = PayrollCycle.keyFor(DateTime.now());
    final snap = await _db
        .collection('payrollRuns')
        .where('monthKey', isEqualTo: monthKey)
        .get();
    if (snap.docs.isEmpty) {
      return 'لا توجد كشوف رواتب محسوبة لشهر $monthKey بعد.';
    }
    final netTotal = snap.docs.fold<double>(
      0,
      (total, doc) =>
          total + ((doc.data()['netSalary'] as num?)?.toDouble() ?? 0),
    );
    return 'كشوف رواتب $monthKey:\n'
        '- عدد الكشوف: ${snap.docs.length}\n'
        '- إجمالي الصافي: ${netTotal.toStringAsFixed(2)}';
  }

  String _teamSetupGuide(UserModel user) {
    if (user.role == EmployeeRole.manager) {
      return 'إضافة موظفين جدد تتم من HR أو مالك النظام. اطلب من HR استخدام الاستيراد الجماعي CSV وتعيين managerId الخاص بك لكل موظف.';
    }
    return 'لإضافة فريق اختبار بسرعة:\n'
        '1. افتح: المزيد ← إدارة الموظفين.\n'
        '2. اضغط استيراد جماعي.\n'
        '3. حمّل نموذج CSV.\n'
        '4. أضف أولاً المدير بدور manager.\n'
        '5. بعد إنشاء المدير، انسخ UID الخاص به من بطاقة الموظف/Firestore.\n'
        '6. في صفوف الـ 10 موظفين ضع managerId = UID المدير و managerName = اسم المدير.\n'
        '7. ارفع الملف. كل الحسابات ستنشأ بكلمة مرور ZW@0000.\n\n'
        'بهذا سيظهر الموظفون تلقائياً في داشبورد المدير وتقارير فريقه.';
  }

  Future<int> _pendingCount(
    String collection,
    UserModel user,
    String status,
  ) async {
    Query<Map<String, dynamic>> query = _db
        .collection(collection)
        .where('status', isEqualTo: status);
    if (user.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: user.uid);
    }
    final snap = await query.get();
    return snap.docs.length;
  }

  Future<List<UserModel>> _scopedEmployees(UserModel user) async {
    if (user.role == EmployeeRole.manager) {
      final modernSnap = await _db
          .collection('users')
          .where('managerIds', arrayContains: user.uid)
          .get();
      final legacySnap = await _db
          .collection('users')
          .where('managerId', isEqualTo: user.uid)
          .get();
      final byId = <String, UserModel>{};
      for (final doc in [...modernSnap.docs, ...legacySnap.docs]) {
        final employee = UserModel.fromFirestore(doc);
        if (employee.isActive &&
            employee.role != EmployeeRole.superAdmin &&
            (employee.managerIds.contains(user.uid) ||
                employee.managerId == user.uid)) {
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
      if (employee.role == EmployeeRole.superAdmin) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _todayAttendance(
    Set<String> employeeIds,
    String today,
  ) async {
    final snap = await _db
        .collection('attendance')
        .where('date', isEqualTo: today)
        .get();
    final map = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      if (employeeIds.contains(userId)) map[userId] = data;
    }
    return map;
  }

  Future<Set<String>> _todayPermissionUsers(
    Set<String> employeeIds,
    String today,
  ) async {
    final snap = await _db
        .collection('permissions')
        .where('requestDate', isEqualTo: today)
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs
        .map((doc) => doc.data()['userId'] as String? ?? '')
        .where(employeeIds.contains)
        .toSet();
  }

  Future<Set<String>> _todayLeaveUsers(Set<String> employeeIds) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final snap = await _db
        .collection('leaves')
        .where('status', isEqualTo: 'approved')
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
        .get();
    final ids = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String? ?? '';
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      if (employeeIds.contains(userId) &&
          endDate != null &&
          endDate.add(const Duration(days: 1)).isAfter(startOfToday)) {
        ids.add(userId);
      }
    }
    return ids;
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _containsAny(String query, List<String> terms) {
    return terms.any((term) => query.contains(_normalize(term)));
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .trim();
  }

  bool _isLateStatus(String status) {
    return status == 'late' ||
        status == 'late_quarter_day' ||
        status == 'late_half_day' ||
        status == 'late_full_day';
  }
}

enum _AttendanceAssistantState { present, late, absent }
