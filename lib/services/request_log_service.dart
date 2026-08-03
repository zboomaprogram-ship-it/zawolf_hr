import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/administrative_request_model.dart';
import '../models/employee_role.dart';
import '../models/user_model.dart';
import '../utils/payroll_cycle.dart';

class RequestLogItem {
  const RequestLogItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.type,
    required this.requestType,
    required this.status,
    required this.submittedAt,
    required this.occursAt,
    required this.occursEndAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.details,
    required this.reason,
    required this.response,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String type;
  final String requestType;
  final String status;
  final DateTime submittedAt;
  final DateTime? occursAt;
  final DateTime? occursEndAt;
  final DateTime? reviewedAt;
  final String reviewedBy;
  final String details;
  final String reason;
  final String response;

  bool get isPending => status.startsWith('pending');

  String get statusLabel {
    if (status == 'approved') return 'مقبول';
    if (status == 'rejected') return 'مرفوض';
    if (status == 'cancelled') return 'ملغي';
    if (status == 'pending_manager') return 'بانتظار موافقة المدير';
    if (status == 'pending_hr') return 'بانتظار موافقة الموارد البشرية';
    if (status == 'pending_ceo') return 'بانتظار موافقة الرئيس التنفيذي';
    if (status == 'pending') return 'قيد المراجعة';
    return status;
  }
}

class RequestLogService {
  RequestLogService._();
  static final RequestLogService instance = RequestLogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, String> _reviewerNameCache = {};

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _combineDateAndTime(dynamic dateValue, dynamic timeValue) {
    final date =
        _date(dateValue) ??
        (dateValue is String ? DateTime.tryParse(dateValue) : null);
    if (date == null) return null;
    if (timeValue is! String || timeValue.trim().isEmpty) return date;
    final parts = timeValue.trim().split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return date;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _reviewerLabel(Map<String, dynamic> data, String reviewerId) {
    final savedName = (data['reviewerName'] as String?)?.trim() ?? '';
    if (savedName.isNotEmpty) return savedName;
    final cached = _reviewerNameCache[reviewerId];
    if (cached != null && cached.isNotEmpty) return cached;
    if (reviewerId.isEmpty) return '';
    if (data['hrReviewedBy'] == reviewerId) return 'الموارد البشرية';
    if (data['managerReviewedBy'] == reviewerId) return 'المدير المباشر';
    return reviewerId;
  }

  Future<void> _cacheReviewerNames(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final ids = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      for (final field in const [
        'reviewedBy',
        'hrReviewedBy',
        'managerReviewedBy',
        'ceoReviewedBy',
      ]) {
        final id = data[field] as String? ?? '';
        if (id.isNotEmpty && !_reviewerNameCache.containsKey(id)) ids.add(id);
      }
    }
    await Future.wait(
      ids.map((id) async {
        try {
          final doc = await _db.collection('users').doc(id).get();
          final name = (doc.data()?['displayName'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) _reviewerNameCache[id] = name;
        } on FirebaseException {
          // The history remains usable when a role cannot read an approver.
        }
      }),
    );
  }

  bool _isInCycle(Map<String, dynamic> data, PayrollCycle cycle) {
    final activityDate =
        _date(data['submittedAt']) ??
        _date(data['createdAt']) ??
        _date(data['reviewedAt']);
    return activityDate != null &&
        !activityDate.isBefore(cycle.start) &&
        activityDate.isBefore(cycle.nextStart);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _scopedDocs(
    String collection,
    UserModel user,
    PayrollCycle cycle,
  ) async {
    if (EmployeeRole.isHr(user.role)) {
      final snapshot = await _db
          .collection(collection)
          .where(
            'submittedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cycle.start),
          )
          .where('submittedAt', isLessThan: Timestamp.fromDate(cycle.nextStart))
          .get();
      return snapshot.docs;
    }

    if (user.role == EmployeeRole.manager ||
        user.role == EmployeeRole.teamLeader) {
      final results = await Future.wait([
        _db
            .collection(collection)
            .where('managerIds', arrayContains: user.uid)
            .get(),
        _db
            .collection(collection)
            .where('managerId', isEqualTo: user.uid)
            .get(),
      ]);
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in results.expand((snapshot) => snapshot.docs)) {
        if (_isInCycle(doc.data(), cycle)) byId[doc.id] = doc;
      }
      return byId.values.toList();
    }

    final snapshot = await _db
        .collection(collection)
        .where('userId', isEqualTo: user.uid)
        .get();
    return snapshot.docs.where((doc) => _isInCycle(doc.data(), cycle)).toList();
  }

  Future<List<RequestLogItem>> getMonthlyLogs(
    UserModel user, {
    PayrollCycle? selectedCycle,
  }) async {
    final cycle = selectedCycle ?? PayrollCycle.forDate(DateTime.now());
    final logs = <RequestLogItem>[];

    Future<void> fetch(
      String collection,
      String type,
      RequestLogItem Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      parse,
    ) async {
      try {
        final docs = await _scopedDocs(collection, user, cycle);
        await _cacheReviewerNames(docs);
        logs.addAll(docs.map(parse));
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }

    RequestLogItem genericItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, {
      required String type,
      required String requestType,
      required String details,
      DateTime? occursAt,
      DateTime? occursEndAt,
    }) {
      final data = doc.data();
      final submittedAt =
          _date(data['submittedAt']) ??
          _date(data['createdAt']) ??
          _date(data['reviewedAt']) ??
          cycle.start;
      final reviewedBy = data['reviewedBy'] as String? ?? '';
      return RequestLogItem(
        id: doc.id,
        employeeId: data['employeeId'] as String? ?? '',
        employeeName: data['employeeName'] as String? ?? 'غير محدد',
        department: data['department'] as String? ?? 'غير محدد',
        type: type,
        requestType: requestType,
        status: data['status'] as String? ?? 'pending',
        submittedAt: submittedAt,
        occursAt: occursAt,
        occursEndAt: occursEndAt,
        reviewedAt: _date(data['reviewedAt']),
        reviewedBy: _reviewerLabel(data, reviewedBy),
        details: details,
        reason: data['reason'] as String? ?? data['notes'] as String? ?? '',
        response:
            data['reviewerComment'] as String? ??
            data['hrReviewerComment'] as String? ??
            '',
      );
    }

    await Future.wait([
      fetch('leaves', 'leave', (doc) {
        final data = doc.data();
        return genericItem(
          doc,
          type: 'leave',
          requestType: _translateLeaveType(
            data['leaveType'] as String? ?? 'annual',
          ),
          details: '${data['numberOfDays'] as int? ?? 1} يوم',
          occursAt: _date(data['startDate']),
          occursEndAt: _date(data['endDate']),
        );
      }),
      fetch('permissions', 'permission', (doc) {
        final data = doc.data();
        final occursAt = _combineDateAndTime(
          data['requestDate'] ?? data['date'],
          data['expectedTime'] ?? data['startTime'],
        );
        final duration = (data['durationMinutes'] as num?)?.toInt() ?? 0;
        return genericItem(
          doc,
          type: 'permission',
          requestType: _translatePermissionType(
            data['permissionType'] as String? ?? '',
          ),
          details: '${data['durationMinutes'] as int? ?? 0} دقيقة',
          occursAt: occursAt,
          occursEndAt: occursAt?.add(Duration(minutes: duration)),
        );
      }),
      fetch('attendanceCorrectionRequests', 'attendance_correction', (doc) {
        final data = doc.data();
        final requested = _date(data['requestedCheckInTime']);
        return genericItem(
          doc,
          type: 'attendance_correction',
          requestType: 'تصحيح وقت حضور',
          details:
              '${data['attendanceDate'] as String? ?? ''}'
              '${requested == null ? '' : ' · ${requested.hour.toString().padLeft(2, '0')}:${requested.minute.toString().padLeft(2, '0')}'}',
          occursAt: requested ?? _date(data['attendanceDate']),
        );
      }),
      fetch('advances', 'advance', (doc) {
        final data = doc.data();
        return genericItem(
          doc,
          type: 'advance',
          requestType: 'سلفة مالية',
          details: '${(data['amount'] as num?)?.toStringAsFixed(2) ?? '0'} EGP',
        );
      }),
      fetch('administrativeRequests', 'administrative', (doc) {
        final data = doc.data();
        return genericItem(
          doc,
          type: 'administrative',
          requestType: AdministrativeRequestCategory.arabicLabel(
            data['category'] as String? ?? AdministrativeRequestCategory.other,
          ),
          details: 'طلب إداري',
        );
      }),
      fetch('resignations', 'resignation', (doc) {
        final data = doc.data();
        final resignationDate = _date(data['resignationDate']);
        return genericItem(
          doc,
          type: 'resignation',
          requestType: 'استقالة',
          details: resignationDate == null
              ? 'طلب استقالة'
              : '${resignationDate.year}/${resignationDate.month}/${resignationDate.day}',
          occursAt: resignationDate,
        );
      }),
    ]);

    logs.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return logs;
  }

  String _translateLeaveType(String type) {
    return switch (type) {
      'annual' || 'day_off' => 'إجازة اعتيادية',
      'sick' => 'إجازة مرضية',
      'casual' => 'إجازة عارضة',
      'unpaid' => 'إجازة بدون راتب',
      'exam' => 'إجازة امتحان',
      'wfh' || 'remote' => 'عمل عن بعد',
      _ => 'إجازة',
    };
  }

  String _translatePermissionType(String type) {
    return switch (type) {
      'early_leave' => 'انصراف مبكر',
      'late_arrival' => 'تأخير حضور',
      'mid_shift_exit' => 'خروج أثناء الدوام',
      'deductible' => 'إذن استقطاعي',
      _ => 'إذن',
    };
  }
}
