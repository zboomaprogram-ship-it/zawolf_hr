import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../models/administrative_request_model.dart';
import '../../../services/attendance_policy_service.dart';
import '../../../services/dashboard_attendance_summary_service.dart';
import '../../../services/google_workspace_service.dart';
import '../domain/hr_period_report.dart';
import '../domain/hr_period_report_repository.dart';

/// Read adapter for the in-app report. It delegates attendance classification
/// to the existing attendance authority so leave/permission precedence and
/// work-schedule rules stay identical to the dashboard and payroll views.
final class FirestoreHrPeriodReportRepository
    implements HrPeriodReportRepository {
  FirestoreHrPeriodReportRepository({
    DashboardAttendanceSummaryService? attendance,
    FirebaseFirestore? firestore,
    AttendancePolicyService? policy,
  }) : _attendance = attendance ?? DashboardAttendanceSummaryService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _policy = policy ?? AttendancePolicyService(firestore: firestore);

  final DashboardAttendanceSummaryService _attendance;
  final FirebaseFirestore _firestore;
  final AttendancePolicyService _policy;

  @override
  Future<String> export({
    required HrReportPeriod period,
    String? employeeId,
  }) async {
    final result = await GoogleWorkspaceService().generateHrPeriodSheet(
      start: period.start,
      end: period.end,
      employeeId: employeeId,
    );
    return result.resourceId;
  }

  @override
  Future<HrPeriodReport> load({
    required UserModel reviewer,
    required HrReportPeriod period,
  }) async {
    final dates = List<DateTime>.generate(
      period.days,
      (index) => period.start.add(Duration(days: index)),
    );
    final details = <DashboardAttendanceDayDetails>[];
    // Three day reads in flight keeps mobile/web responsive without unbounded
    // request fan-out for the allowed 31-day period.
    for (var index = 0; index < dates.length; index += 3) {
      final end = (index + 3).clamp(0, dates.length);
      details.addAll(
        await Future.wait(
          dates
              .sublist(index, end)
              .map((date) => _attendance.loadDayDetails(reviewer, date)),
        ),
      );
    }
    final auxiliary = await _loadAuxiliary(period);
    final rawAttendance = auxiliary.attendance;
    final employees = <String, HrReportEmployee>{};
    final records = <HrAttendanceRecord>[];
    for (final day in details) {
      for (final person in day.people) {
        final employee = HrReportEmployee(
          id: person.employee.uid,
          name: person.employee.displayName,
          code: person.employee.employeeId,
          department: person.employee.department,
          baseMonthlySalary: person.employee.baseMonthlySalary,
          salaryCurrency: person.employee.salaryCurrency,
        );
        employees[employee.id] = employee;
        final raw = rawAttendance['${employee.id}:${_key(day.summary.date)}'];
        final companyDayOff = auxiliary.companyDaysOff[_key(day.summary.date)];
        final checkIn = person.checkInTime ?? _dateTime(raw?['checkInTime']);
        final checkOut = person.checkOutTime ?? _dateTime(raw?['checkOutTime']);
        final lateMinutes =
            person.lateMinutes > 0
                ? person.lateMinutes
                : (raw?['lateMinutes'] as num?)?.toInt() ?? 0;
        final resolvedStatus =
            checkIn != null && person.status == 'day_off'
                ? ((raw?['isLate'] == true || lateMinutes > 0)
                    ? 'late'
                    : 'present')
                : companyDayOff != null && checkIn == null
                ? 'day_off'
                : person.status;
        records.add(
          HrAttendanceRecord(
            employee: employee,
            date: day.summary.date,
            status: resolvedStatus,
            checkIn: checkIn,
            checkOut: checkOut,
            lateMinutes: lateMinutes,
            deductionReason:
                raw == null || !_hasDeduction(raw)
                    ? null
                    : _deductionReason(raw, 'الحضور والانصراف'),
            deductionStatus: _string(raw?['salaryDeductionApprovalStatus']),
            statusDetail: _attendanceStatusDetail(
              resolvedStatus,
              employee.id,
              day.summary.date,
              auxiliary.leaves,
              companyDayOff,
            ),
          ),
        );
      }
    }
    final employeeList =
        employees.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    final employeeById = {
      for (final employee in employeeList) employee.id: employee,
    };
    final requests = _requestRecords(auxiliary, employeeById, period);
    final policy = await _policy.getPolicyConfig();
    final deductions = _deductionRecords(
      auxiliary.attendance.values,
      auxiliary.permissions,
      auxiliary.manualDeductions,
      employeeById,
      period,
      policy.payrollWorkDaysPerMonth,
    );
    return HrPeriodReport(
      period: period,
      records: records,
      employees: employeeList,
      requests: requests,
      deductions: deductions,
    );
  }

  Future<_ReportAuxiliary> _loadAuxiliary(HrReportPeriod period) async {
    final startKey = _key(period.start);
    final endKey = _key(period.end);
    final endOfPeriod = Timestamp.fromDate(
      DateTime(period.end.year, period.end.month, period.end.day, 23, 59, 59),
    );
    final core = await Future.wait([
      _firestore
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: endKey)
          .get(),
      _firestore
          .collection('permissions')
          .where('requestDate', isGreaterThanOrEqualTo: startKey)
          .where('requestDate', isLessThanOrEqualTo: endKey)
          .limit(5000)
          .get(),
      _firestore
          .collection('leaves')
          .where('startDate', isLessThanOrEqualTo: endOfPeriod)
          .limit(5000)
          .get(),
      _firestore
          .collection('manual_deductions')
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThanOrEqualTo: endKey)
          .limit(5000)
          .get(),
      _firestore
          .collection('companyDayOffs')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: endKey)
          .limit(100)
          .get(),
    ]);
    final requestCollections = <String>[
      'advances',
      'meetingRequests',
      'administrativeRequests',
      'customRequests',
      'attendanceCorrectionRequests',
      'complaints',
      'resignations',
      'employeeDeletionRequests',
      'hiringRequests',
    ];
    final extra = await Future.wait(requestCollections.map(_boundedCollection));
    final attendance = core[0];
    return _ReportAuxiliary(
      attendance: {
        for (final doc in attendance.docs)
          '${doc.data()['userId'] ?? ''}:${doc.data()['date'] ?? ''}':
              doc.data(),
      },
      permissions: core[1].docs.map((doc) => doc.data()).toList(),
      leaves: core[2].docs.map((doc) => doc.data()).toList(),
      manualDeductions: core[3].docs.map((doc) => doc.data()).toList(),
      companyDaysOff: {
        for (final doc in core[4].docs)
          if (doc.data()['isActive'] != false)
            '${doc.data()['date'] ?? doc.id}':
                _string(doc.data()['title']) ?? 'عطلة رسمية للشركة',
      },
      otherRequests: {
        for (var index = 0; index < requestCollections.length; index++)
          requestCollections[index]: extra[index],
      },
    );
  }

  Future<List<Map<String, dynamic>>> _boundedCollection(String name) async {
    try {
      final snapshot = await _firestore.collection(name).limit(1000).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (error) {
      // A report should remain useful when an optional request module is not
      // enabled for a tenant or its rules have not been deployed yet.
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return const [];
      }
      rethrow;
    }
  }

  List<HrRequestRecord> _requestRecords(
    _ReportAuxiliary auxiliary,
    Map<String, HrReportEmployee> users,
    HrReportPeriod period,
  ) {
    final output = <HrRequestRecord>[];
    void add({
      required Map<String, dynamic> item,
      required String type,
      required Object? dateValue,
      Object? endValue,
      String? reason,
      List<String> userFields = const [
        'userId',
        'requesterId',
        'requestedById',
      ],
    }) {
      final employee = _employee(item, users, userFields);
      final date = _date(dateValue);
      final end = _date(endValue);
      if (employee == null ||
          date == null ||
          (end ?? date).isBefore(period.start) ||
          date.isAfter(period.end)) {
        return;
      }
      output.add(
        HrRequestRecord(
          employee: employee,
          date: date,
          endDate: end,
          type: type,
          status: _status(item['status']),
          reason: reason,
        ),
      );
    }

    for (final item in auxiliary.permissions) {
      final date = _date(item['requestDate']);
      if (date != null) {
        add(
          item: item,
          type: _permissionLabel(item),
          dateValue: date,
          reason: _string(item['reason']),
        );
      }
    }
    for (final item in auxiliary.leaves) {
      final start = _date(item['startDate']);
      final end = _date(item['endDate']);
      if (start != null && end != null) {
        add(
          item: item,
          type: _leaveLabel(item['leaveType']),
          dateValue: start,
          endValue: end,
          reason: _string(item['reason']),
        );
      }
    }

    final sources = auxiliary.otherRequests;
    for (final item in sources['advances'] ?? const []) {
      add(
        item: item,
        type: 'سلفة مالية',
        dateValue: item['submittedAt'],
        reason: _moneyReason(item),
      );
    }
    for (final item in sources['meetingRequests'] ?? const []) {
      add(
        item: item,
        type: 'طلب اجتماع',
        dateValue: item['startAt'] ?? item['createdAt'],
        endValue: item['endAt'],
        reason: _join([_string(item['roomName']), _string(item['purpose'])]),
        userFields: const ['requesterId'],
      );
    }
    for (final item in sources['administrativeRequests'] ?? const []) {
      final category =
          _string(item['category']) ?? _string(item['requestType']) ?? '';
      add(
        item: item,
        type: _administrativeLabel(item, category),
        dateValue: item['missionDate'] ?? item['submittedAt'],
        reason: _join([
          _string(item['siteName']),
          _string(item['notes']),
          _string(item['description']),
        ]),
      );
    }
    for (final item in sources['customRequests'] ?? const []) {
      add(
        item: item,
        type:
            _string(item['typeNameAr']) ?? _string(item['title']) ?? 'طلب مخصص',
        dateValue: item['createdAt'],
        reason: _string(item['description']),
        userFields: const ['requesterId'],
      );
    }
    for (final item in sources['attendanceCorrectionRequests'] ?? const []) {
      add(
        item: item,
        type: 'تصحيح حضور',
        dateValue:
            item['attendanceDate'] ??
            item['requestedCheckInTime'] ??
            item['submittedAt'],
        reason: _join([_string(item['reason']), _timeReason(item)]),
      );
    }
    for (final item in sources['complaints'] ?? const []) {
      add(
        item: item,
        type: 'شكوى',
        dateValue: item['submittedAt'],
        reason: _join([_string(item['title']), _string(item['body'])]),
      );
    }
    for (final item in sources['resignations'] ?? const []) {
      add(
        item: item,
        type: 'استقالة',
        dateValue: item['resignationDate'] ?? item['submittedAt'],
        reason: _string(item['reason']),
      );
    }
    for (final item in sources['employeeDeletionRequests'] ?? const []) {
      add(
        item: item,
        type: 'إنهاء حساب موظف',
        dateValue: item['requestedAt'],
        reason: _string(item['reason']),
        userFields: const ['employeeId', 'requesterId'],
      );
    }
    for (final item in sources['hiringRequests'] ?? const []) {
      add(
        item: item,
        type:
            'طلب تعيين: ${_string(item['proposedEmployeeName']) ?? 'موظف جديد'}',
        dateValue: item['assignmentDate'] ?? item['submittedAt'],
        reason: _join([_string(item['jobTitle']), _moneyReason(item)]),
        userFields: const ['existingEmployeeUid', 'requestedById'],
      );
    }
    output.sort((a, b) => b.date.compareTo(a.date));
    return output;
  }

  List<HrDeductionRecord> _deductionRecords(
    Iterable<Map<String, dynamic>> attendance,
    List<Map<String, dynamic>> permissions,
    List<Map<String, dynamic>> manual,
    Map<String, HrReportEmployee> users,
    HrReportPeriod period,
    int payrollWorkDaysPerMonth,
  ) {
    final output = <HrDeductionRecord>[];
    void add(Map<String, dynamic> item, String source, Object? dateValue) {
      final employee = users[item['userId']];
      final date = _date(dateValue);
      final fraction =
          (item['salaryDeductionFraction'] as num?)?.toDouble() ??
          (item['fraction'] as num?)?.toDouble() ??
          (item['dayFraction'] as num?)?.toDouble() ??
          0;
      var amount =
          (item['salaryDeductionAmount'] as num?)?.toDouble() ??
          (item['amount'] as num?)?.toDouble() ??
          0;
      final status = _status(
        item['salaryDeductionApprovalStatus'] ?? item['status'],
      );
      if (employee == null ||
          date == null ||
          date.isBefore(period.start) ||
          date.isAfter(period.end) ||
          (fraction <= 0 && amount <= 0 && status == 'none')) {
        return;
      }
      if (amount <= 0 && fraction > 0 && employee.baseMonthlySalary > 0) {
        amount =
            employee.baseMonthlySalary / payrollWorkDaysPerMonth * fraction;
      }
      output.add(
        HrDeductionRecord(
          employee: employee,
          date: date,
          reason: _deductionReason(item, source),
          status: status,
          amount: amount,
          fraction: fraction,
          source: source,
          detail: _deductionDetail(item, source),
        ),
      );
    }

    for (final item in attendance) {
      add(item, 'الحضور والانصراف', item['date']);
    }
    for (final item in permissions) {
      add(item, 'إذن', item['requestDate']);
    }
    for (final item in manual) {
      add(item, 'خصم إداري', item['dateKey']);
    }
    output.sort((a, b) => b.date.compareTo(a.date));
    return output;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return DateTime(
        value.toDate().year,
        value.toDate().month,
        value.toDate().day,
      );
    }
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is String) {
      return DateTime.tryParse(
        value.length >= 10 ? value.substring(0, 10) : value,
      );
    }
    return null;
  }

  DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  HrReportEmployee? _employee(
    Map<String, dynamic> item,
    Map<String, HrReportEmployee> users,
    List<String> fields,
  ) {
    for (final field in fields) {
      final id = _string(item[field]);
      if (id != null && users[id] != null) return users[id];
    }
    return null;
  }

  String _leaveLabel(Object? value) => switch (_string(value)) {
    'annual' || 'day_off' => 'إجازة اعتيادية',
    'sick' => 'إجازة مرضية',
    'casual' => 'إجازة عارضة',
    'unpaid' => 'إجازة بدون راتب',
    'exam' => 'إجازة امتحان',
    'wfh' || 'remote' => 'عمل عن بعد',
    _ => 'إجازة',
  };

  String _permissionLabel(Map<String, dynamic> item) => switch (_string(
    item['permissionType'],
  )) {
    'early_leave' => 'إذن انصراف مبكر',
    'late_arrival' => 'إذن تأخير حضور',
    'emergency' => 'إذن طارئ',
    _ => 'إذن وقتي',
  };

  String _administrativeLabel(Map<String, dynamic> item, String category) {
    final saved = _string(item['categoryLabel']);
    if (saved != null) return saved;
    if (category == 'company_os') return 'خدمات تقنية وتشغيلية';
    if (category == 'company_expense') return 'مصروفات ومدفوعات الشركة';
    return AdministrativeRequestCategory.arabicLabel(category);
  }

  String? _attendanceStatusDetail(
    String status,
    String userId,
    DateTime date,
    List<Map<String, dynamic>> leaves,
    String? companyDayOff,
  ) {
    if (status != 'day_off') return null;
    if (companyDayOff != null) return 'عطلة رسمية: $companyDayOff';
    if (date.weekday == DateTime.friday) return 'عطلة الجمعة';
    for (final leave in leaves) {
      if (_string(leave['userId']) != userId ||
          _status(leave['status']) != 'approved') {
        continue;
      }
      final start = _date(leave['startDate']);
      final end = _date(leave['endDate']);
      if (start != null &&
          end != null &&
          !date.isBefore(start) &&
          !date.isAfter(end)) {
        return _leaveLabel(leave['leaveType']);
      }
    }
    return 'راحة أسبوعية / يوم غير مجدول';
  }

  String? _moneyReason(Map<String, dynamic> item) {
    final value =
        (item['amount'] as num?)?.toDouble() ??
        (item['baseMonthlySalary'] as num?)?.toDouble();
    if (value == null) return null;
    return '${value.toStringAsFixed(2)} ${_string(item['salaryCurrency']) ?? 'EGP'}';
  }

  String? _timeReason(Map<String, dynamic> item) {
    final checkIn = _dateTime(
      item['requestedCheckInTime'] ?? item['checkInTime'],
    );
    final checkOut = _dateTime(
      item['requestedCheckOutTime'] ?? item['checkOutTime'],
    );
    if (checkIn == null && checkOut == null) return null;
    final format = DateFormat('hh:mm a', 'ar');
    return _join([
      checkIn == null ? null : 'الحضور ${format.format(checkIn)}',
      checkOut == null ? null : 'الانصراف ${format.format(checkOut)}',
    ]);
  }

  String? _deductionDetail(Map<String, dynamic> item, String source) {
    final checkIn = _dateTime(item['checkInTime']);
    final checkOut = _dateTime(item['checkOutTime']);
    final lateMinutes = (item['lateMinutes'] as num?)?.toInt() ?? 0;
    final format = DateFormat('hh:mm a', 'ar');
    final details = <String?>[];
    if (source == 'الحضور والانصراف') {
      if (checkIn == null) {
        details.add('لم يسجل الموظف حضوراً في يوم عمل مجدول');
      } else {
        details.add('وقت الحضور ${format.format(checkIn)}');
        details.add(
          checkOut == null
              ? 'لم يسجل الانصراف'
              : 'وقت الانصراف ${format.format(checkOut)}',
        );
      }
      if (lateMinutes > 0) details.add('تأخير $lateMinutes دقيقة');
    } else if (source == 'إذن') {
      details.add(_permissionLabel(item));
      details.add(
        _join([_string(item['expectedTime']), _string(item['reason'])]),
      );
    } else {
      details.add(_string(item['notes']) ?? _string(item['reason']));
    }
    return _join(details);
  }

  String _deductionReason(Map<String, dynamic> item, String source) {
    final label =
        _string(item['salaryDeductionLabel']) ?? _string(item['fractionLabel']);
    var cause =
        _string(item['salaryDeductionReason']) ??
        _string(item['deductionReason']) ??
        _string(item['reason']);
    if (cause == null && source == 'الحضور والانصراف') {
      final checkIn = _dateTime(item['checkInTime']);
      final checkOut = _dateTime(item['checkOutTime']);
      final lateMinutes = (item['lateMinutes'] as num?)?.toInt() ?? 0;
      if (checkIn == null) {
        cause = 'غياب دون تسجيل حضور';
      } else if (lateMinutes > 0) {
        cause = 'تأخير حضور $lateMinutes دقيقة';
      } else if (checkOut == null) {
        cause = 'عدم تسجيل الانصراف';
      }
    }
    final parts = <String>[];
    for (final value in [label, cause]) {
      if (value != null && !parts.contains(value)) parts.add(value);
    }
    return parts.isEmpty ? 'خصم راتب' : parts.join(' — ');
  }

  bool _hasDeduction(Map<String, dynamic> item) =>
      ((item['salaryDeductionFraction'] as num?)?.toDouble() ?? 0) > 0 ||
      ((item['salaryDeductionAmount'] as num?)?.toDouble() ?? 0) > 0 ||
      _string(item['salaryDeductionApprovalStatus']) != null ||
      _string(item['salaryDeductionCode']) != null;

  String? _join(Iterable<String?> values) {
    final parts =
        values
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _status(Object? value) =>
      value?.toString().trim().isEmpty ?? true
          ? 'pending'
          : value.toString().trim();

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String? _string(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _ReportAuxiliary {
  const _ReportAuxiliary({
    required this.attendance,
    required this.permissions,
    required this.leaves,
    required this.manualDeductions,
    required this.companyDaysOff,
    required this.otherRequests,
  });
  final Map<String, Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> permissions;
  final List<Map<String, dynamic>> leaves;
  final List<Map<String, dynamic>> manualDeductions;
  final Map<String, String> companyDaysOff;
  final Map<String, List<Map<String, dynamic>>> otherRequests;
}
