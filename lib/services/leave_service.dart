import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:zawolf_hr/models/employee_role.dart';
import '../models/user_model.dart';
import '../models/leave_model.dart';
import '../models/leave_type_policy.dart';
import '../models/leave_entitlement_policy.dart';
import '../models/manager_approval_chain.dart';
import 'audit_log_service.dart';
import 'request_approval_policy_service.dart';
import 'role_notification_service.dart';
import 'attendance_reconciliation_service.dart';

class LeaveService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final RequestApprovalPolicyService _approvalPolicyService =
      RequestApprovalPolicyService();
  final AttendanceReconciliationService _reconciliationService =
      AttendanceReconciliationService();

  static void validateRequest(LeaveModel request, {DateTime? now}) {
    if (!LeaveTypePolicy.supportedTypes.contains(request.leaveType)) {
      throw Exception('اختر نوع إجازة صحيحاً.');
    }
    if ((request.reason ?? '').trim().isEmpty) {
      throw Exception('يجب كتابة سبب الإجازة.');
    }
    if (request.workHandoverTo.trim().isEmpty) {
      throw Exception('يجب تحديد من سيقوم بالعمل أثناء الإجازة.');
    }
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final start = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final end = DateTime(
      request.endDate.year,
      request.endDate.month,
      request.endDate.day,
    );
    if (end.isBefore(start)) {
      throw Exception('تاريخ نهاية الإجازة يسبق تاريخ البداية.');
    }
    if (start.isBefore(today)) {
      throw Exception('لا يمكن تقديم طلب إجازة عن يوم سابق.');
    }
    if (LeaveTypePolicy.requiresTwoDayNotice(request.leaveType) &&
        start.isBefore(today.add(const Duration(days: 2)))) {
      throw Exception(
        'الإجازة العادية يجب تقديمها قبل موعدها بيومين على الأقل.',
      );
    }
    if (request.leaveType == LeaveTypePolicy.exam) {
      if (start.difference(today).inDays < 10) {
        throw Exception(
          'يجب تقديم طلب إجازة الامتحان قبل موعد الامتحان بعشرة أيام على الأقل.',
        );
      }
      if ((request.attachmentUrl ?? '').trim().isEmpty) {
        throw Exception(
          'يجب إرفاق جدول الامتحان أو ما يفيد دخول الامتحان فعلياً.',
        );
      }
    }
    if (request.leaveType == LeaveTypePolicy.paternity &&
        request.numberOfDays != 1) {
      throw Exception('إجازة المولود تكون ليوم واحد فقط.');
    }
  }

  static void validateBalance(LeaveModel request, LeaveBalance balance) {
    if (request.leaveType == LeaveTypePolicy.normal &&
        request.numberOfDays > balance.daysOff) {
      throw Exception('رصيد الإجازات الكلي غير كافٍ.');
    }
    if (request.leaveType == LeaveTypePolicy.casual) {
      if (request.numberOfDays > 2) {
        throw Exception(
          'الحد الأقصى للإجازة العارضة يومان متتاليان في المرة الواحدة.',
        );
      }
      if (request.numberOfDays > balance.casual) {
        throw Exception('رصيد الإجازات العارضة غير كافٍ.');
      }
      if (request.numberOfDays > balance.daysOff) {
        throw Exception('رصيد الإجازات الكلي غير كافٍ.');
      }
    }
  }

  static bool dateRangesOverlap(LeaveModel first, LeaveModel second) {
    return first.startDate.isBefore(
          second.endDate.add(const Duration(days: 1)),
        ) &&
        first.endDate.isAfter(
          second.startDate.subtract(const Duration(days: 1)),
        );
  }

  /// Counts only scheduled working days. The default employee schedule already
  /// treats Friday as a weekly day off; active company days off are also
  /// excluded. Keeping this calculation in the service prevents a browser
  /// client from charging a leave balance for a non-working day.
  static int countChargeableDays({
    required DateTime start,
    required DateTime end,
    required WorkSchedule schedule,
    Set<String> companyDayOffKeys = const <String>{},
  }) {
    var count = 0;
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-'
          '${cursor.month.toString().padLeft(2, '0')}-'
          '${cursor.day.toString().padLeft(2, '0')}';
      if (schedule.isWorkDay(cursor) && !companyDayOffKeys.contains(key)) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  Future<int> _chargeableDays(LeaveModel request, UserModel employee) async {
    final startKey =
        '${request.startDate.year.toString().padLeft(4, '0')}-'
        '${request.startDate.month.toString().padLeft(2, '0')}-'
        '${request.startDate.day.toString().padLeft(2, '0')}';
    final endKey =
        '${request.endDate.year.toString().padLeft(4, '0')}-'
        '${request.endDate.month.toString().padLeft(2, '0')}-'
        '${request.endDate.day.toString().padLeft(2, '0')}';
    final dayOffs =
        await _db
            .collection('companyDayOffs')
            .where('date', isGreaterThanOrEqualTo: startKey)
            .where('date', isLessThanOrEqualTo: endKey)
            .get();
    final keys =
        dayOffs.docs
            .where((doc) => doc.data()['isActive'] == true)
            .map((doc) => (doc.data()['date'] as String? ?? doc.id).trim())
            .toSet();
    return countChargeableDays(
      start: request.startDate,
      end: request.endDate,
      schedule: employee.workSchedule,
      companyDayOffKeys: keys,
    );
  }

  String _attachmentContentType(String pathOrExtension) {
    final extension = pathOrExtension.split('.').last.trim().toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/pdf';
    }
  }

  List<String> _approvalManagerIds(UserModel employee) {
    return ManagerApprovalChain.orderedIds(
      employee.managerIds,
      fallbackId: employee.managerId,
      teamLeaderId: employee.teamLeaderId,
    );
  }

  List<String> _approvalManagerNames(UserModel employee, String? fallbackName) {
    final ids = _approvalManagerIds(employee);
    return ManagerApprovalChain.orderedNames(
      orderedIds: ids,
      managerIds: employee.managerIds,
      managerNames: employee.managerNames,
      teamLeaderId: employee.teamLeaderId,
      teamLeaderName: employee.teamLeaderName,
      fallbackManagerId: employee.managerId,
      fallbackManagerName: fallbackName,
    );
  }

  Map<String, dynamic> _nextManagerApprovalUpdate({
    required Map<String, dynamic> data,
    required String reviewerId,
    required String reviewerRole,
    required String reviewerName,
  }) {
    final managerIds =
        (data['managerIds'] as List<dynamic>?)
            ?.whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList() ??
        <String>[];
    final managerNames =
        (data['managerNames'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final currentManagerId = data['managerId'] as String? ?? '';
    final savedIndex = data['managerApprovalIndex'] as int?;
    final currentIndex = ManagerApprovalChain.currentIndex(
      managerIds: managerIds,
      currentManagerId: currentManagerId,
      savedIndex: savedIndex,
    );
    final nextIndex = currentIndex + 1;
    final trail = {
      'reviewerId': reviewerId,
      'reviewerRole': reviewerRole,
      'reviewerName': reviewerName,
      'action': 'approved',
      'reviewedAt': Timestamp.now(),
      'stage': currentIndex < 0 ? 0 : currentIndex,
    };

    if (nextIndex >= 0 && nextIndex < managerIds.length) {
      return {
        'status': 'pending_manager',
        'managerId': managerIds[nextIndex],
        'managerName':
            nextIndex < managerNames.length ? managerNames[nextIndex] : null,
        'managerApprovalIndex': nextIndex,
        'managerApprovalTrail': FieldValue.arrayUnion([trail]),
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewerName': reviewerName,
        'approvalHistory': FieldValue.arrayUnion([trail]),
      };
    }

    return {
      // Every submitted leave goes to HR after its manager stages. Long
      // leave is then escalated by HR to the assigned CEO as the final stage.
      // A manager must never be inferred to be the CEO merely because they
      // are last in the employee's reporting list.
      'status': 'pending_hr',
      'managerApprovalIndex': managerIds.isEmpty ? 0 : managerIds.length - 1,
      'managerApprovalTrail': FieldValue.arrayUnion([trail]),
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerName': reviewerName,
      'approvalHistory': FieldValue.arrayUnion([trail]),
    };
  }

  Map<String, dynamic> _approvalEvent({
    required String stage,
    required String status,
    required String actorId,
    required String actorName,
    String? comment,
  }) {
    return {
      'stage': stage,
      'status': status,
      'actorId': actorId,
      'actorName': actorName,
      'timestamp': Timestamp.now(),
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    };
  }

  /// Long leave is reviewed by the canonical active CEO account, never by an
  /// arbitrary manager in the employee's reporting chain. CEO-100 is the
  /// organisation's explicit assignment for this workflow.
  Future<({String id, String name})> _assignedCeo() async {
    final results =
        await _db
            .collection('users')
            .where('employeeId', isEqualTo: 'CEO-100')
            .limit(1)
            .get();
    if (results.docs.isEmpty) {
      throw StateError('تعذر تحديد حساب CEO-100 النشط لمسار الإجازة.');
    }
    final data = results.docs.first.data();
    if (data['isActive'] == false) {
      throw StateError('حساب CEO-100 غير نشط لمسار الإجازة.');
    }
    return (
      id: results.docs.first.id,
      name: (data['displayName'] as String? ?? '').trim(),
    );
  }

  // Upload certificate attachment to Firebase Storage (supports mobile & web via bytes)
  Future<String> uploadAttachment({
    required String leaveId,
    required String userId,
    required Uint8List fileBytes,
    required String fileExtension,
  }) async {
    final ref = _storage.ref().child(
      'leaves/$userId/${leaveId}_cert.$fileExtension',
    );
    final uploadTask = await ref.putData(
      fileBytes,
      SettableMetadata(contentType: _attachmentContentType(fileExtension)),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // Upload certificate from local file path (mobile fallback)
  Future<String> uploadAttachmentFromFile({
    required String leaveId,
    required String userId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final fileExtension = filePath.split('.').last;
    final ref = _storage.ref().child(
      'leaves/$userId/${leaveId}_cert.$fileExtension',
    );
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: _attachmentContentType(fileExtension)),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // Submit leave request
  Future<void> submitLeaveRequest(LeaveModel req, UserModel employee) async {
    validateRequest(req);
    final chargedDays = await _chargeableDays(req, employee);
    if (chargedDays == 0) {
      throw Exception(
        'الفترة المحددة لا تحتوي أيام عمل؛ لا يلزم طلب إجازة لها.',
      );
    }
    final normalizedRequest = LeaveModel(
      leaveId: req.leaveId,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      leaveType: req.leaveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: chargedDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      workHandoverTo: req.workHandoverTo,
      status: req.status,
      submittedAt: req.submittedAt,
      convertToAnnual: req.convertToAnnual,
    );
    req = normalizedRequest;
    if (req.leaveType == LeaveTypePolicy.paternity) {
      final prior =
          await _db
              .collection('leaves')
              .where('userId', isEqualTo: req.userId)
              .where('leaveType', isEqualTo: LeaveTypePolicy.paternity)
              .where(
                'status',
                whereIn: const [
                  'approved',
                  'pending',
                  'pending_manager',
                  'pending_hr',
                  'pending_ceo',
                ],
              )
              .limit(3)
              .get();
      if (prior.docs.length >= 3) {
        throw Exception(
          'تم استنفاد الحد الأقصى لإجازة المولود (3 مرات طوال مدة الخدمة).',
        );
      }
    }
    final approvalPolicy = await _approvalPolicyService.getPolicy();
    if (req.leaveType != LeaveTypePolicy.unpaid &&
        employee.hiringDate == null) {
      throw Exception(
        'يجب أن تسجل إدارة الموارد البشرية تاريخ التعيين قبل طلب إجازة.',
      );
    }
    final probationConversion =
        req.leaveType != LeaveTypePolicy.unpaid &&
        LeaveEntitlementPolicy.isOnProbation(
          employee.hiringDate,
          onDate: req.startDate,
        );
    final effectiveType =
        probationConversion ? LeaveTypePolicy.unpaid : req.leaveType;
    final effectiveRequest = LeaveModel(
      leaveId: req.leaveId,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      leaveType: effectiveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      workHandoverTo: req.workHandoverTo,
      status: req.status,
      submittedAt: req.submittedAt,
      convertToAnnual: req.convertToAnnual,
    );
    validateBalance(effectiveRequest, employee.leaveBalance);

    // 1. Validate overlaps (basic check against other active leaves)
    final overlaps =
        await _db
            .collection('leaves')
            .where('userId', isEqualTo: req.userId)
            .where(
              'status',
              whereIn: [
                'approved',
                'pending_hr',
                'pending_manager',
                'pending_ceo',
              ],
            )
            .where(
              'startDate',
              isLessThanOrEqualTo: Timestamp.fromDate(req.endDate),
            )
            .get();

    for (final doc in overlaps.docs) {
      final existing = LeaveModel.fromFirestore(doc);
      if (dateRangesOverlap(req, existing)) {
        throw Exception(
          'يوجد طلب إجازة آخر متداخل من '
          '${existing.startDate.year}-${existing.startDate.month.toString().padLeft(2, '0')}-${existing.startDate.day.toString().padLeft(2, '0')} '
          'إلى '
          '${existing.endDate.year}-${existing.endDate.month.toString().padLeft(2, '0')}-${existing.endDate.day.toString().padLeft(2, '0')}. '
          'اختر تواريخ أخرى غير متداخلة.',
        );
      }
    }

    final reqRef = _db.collection('leaves').doc();
    final managerIds = _approvalManagerIds(employee);
    final managerNames = _approvalManagerNames(employee, employee.managerName);
    final usesHrFallback = ManagerApprovalChain.usesHrFallback(
      isSuperAdmin: employee.role == EmployeeRole.superAdmin,
      managerIds: managerIds,
    );
    final isAutoApprovedCasual = effectiveType == LeaveTypePolicy.casual;
    if (!isAutoApprovedCasual && managerIds.isEmpty && !usesHrFallback) {
      throw Exception(
        'لا يمكن إرسال الطلب قبل تعيين مدير مباشر للموظف من إدارة الحسابات.',
      );
    }
    final approvalManagerIds = isAutoApprovedCasual ? <String>[] : managerIds;
    final approvalManagerNames =
        isAutoApprovedCasual ? <String>[] : managerNames;
    final firstManagerId =
        approvalManagerIds.isEmpty ? '' : approvalManagerIds.first;
    final requiresCeoApproval =
        !isAutoApprovedCasual &&
        LeaveTypePolicy.requiresCeoApproval(req.leaveType, req.numberOfDays);
    final assignedCeo = requiresCeoApproval ? await _assignedCeo() : null;
    final finalModel = LeaveModel(
      leaveId: reqRef.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: firstManagerId,
      leaveType: effectiveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      workHandoverTo: req.workHandoverTo,
      status:
          isAutoApprovedCasual
              ? 'approved'
              : (usesHrFallback ? 'pending_hr' : 'pending_manager'),
      submittedAt: DateTime.now(),
      convertToAnnual:
          req.convertToAnnual && effectiveType == LeaveTypePolicy.sick,
    );

    final leaveData = {
      ...finalModel.toFirestore(),
      'deductsLeaveBalance':
          LeaveTypePolicy.balanceKeys(effectiveType).isNotEmpty,
      if (LeaveTypePolicy.balanceKey(effectiveType) != null)
        'leaveBalanceKey': LeaveTypePolicy.balanceKey(effectiveType),
      if (LeaveTypePolicy.balanceKeys(effectiveType).isNotEmpty)
        'leaveBalanceKeys': LeaveTypePolicy.balanceKeys(effectiveType),
      'requiresFullDaySalaryDeduction':
          LeaveTypePolicy.requiresFullDaySalaryDeduction(effectiveType),
      'managerIds': approvalManagerIds,
      'managerNames': approvalManagerNames,
      'managerApprovalIndex': 0,
      'managerApprovalTotal': approvalManagerIds.length,
      'managerApprovalTrail': <Map<String, dynamic>>[],
      'requiresHrApproval':
          !isAutoApprovedCasual &&
          (requiresCeoApproval ||
              approvalPolicy.requireHrAfterManagerApproval ||
              usesHrFallback),
      'approvalHistory': [
        _approvalEvent(
          stage: 'submitted',
          status: 'completed',
          actorId: employee.uid,
          actorName: employee.displayName,
        ),
        if (isAutoApprovedCasual)
          _approvalEvent(
            stage: 'auto_approved',
            status: 'approved',
            actorId: 'system',
            actorName: 'النظام',
          ),
      ],
      'requiresCeoApproval': requiresCeoApproval,
      if (assignedCeo != null) ...{
        'ceoId': assignedCeo.id,
        'ceoName': assignedCeo.name,
        'ceoApprovalViaManagerChain': false,
      },
      if (probationConversion) ...{
        'originalLeaveType': req.leaveType,
        'probationConverted': true,
      },
      if (isAutoApprovedCasual) ...{
        'autoApproved': true,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'system',
        'reviewerName': 'النظام (اعتماد تلقائي)',
        'reviewerComment': 'تم اعتماد الإجازة العارضة تلقائياً.',
      },
    };

    if (isAutoApprovedCasual) {
      final userRef = _db.collection('users').doc(employee.uid);
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception('حساب الموظف غير موجود.');
        final latestBalance =
            UserModel.fromFirestore(userSnapshot).leaveBalance;
        validateBalance(effectiveRequest, latestBalance);
        transaction.set(reqRef, leaveData);
        transaction.update(userRef, {
          'leaveBalance.casual': FieldValue.increment(-req.numberOfDays),
          'leaveBalance.daysOff': FieldValue.increment(-req.numberOfDays),
          'lastAutoApprovedCasualLeaveId': reqRef.id,
        });
      });
      try {
        await _createNotification(
          recipientId: employee.uid,
          notificationId: 'leave_auto_approved_${reqRef.id}',
          type: 'leave_auto_approved',
          title: 'تم اعتماد الإجازة العارضة',
          body:
              'تم اعتماد الإجازة العارضة تلقائياً وخصم ${req.numberOfDays} يوم من رصيد العارضة والرصيد الكلي.',
          data: {'leaveId': reqRef.id},
        );
      } catch (_) {
        // The approved leave must not be reported as failed after it was saved.
      }
      try {
        await _reconciliationService.reconcileApprovedLeave(finalModel);
      } catch (_) {
        // Reconciliation can be retried independently without duplicating leave.
      }
      return;
    }

    await reqRef.set(leaveData);

    // The leave is authoritative once its document is committed. A
    // notification permission or transient delivery error must never make the
    // employee see a failed submission and retry an already saved request.
    try {
      if (usesHrFallback) {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrManager,
          includeSuperAdmins: false,
          type: 'leave_request_submitted',
          title: 'طلب إجازة بدون مدير معيّن',
          body:
              '${req.employeeName} أرسل ${LeaveTypePolicy.arabicLabel(req.leaveType)} وينتظر قرار HR.',
          data: {'leaveId': reqRef.id},
        );
      } else {
        await _createNotification(
          recipientId: firstManagerId,
          type: 'leave_request_submitted',
          title: 'طلب إجازة بانتظار موافقتك',
          body:
              'يطلب ${req.employeeName} ${LeaveTypePolicy.arabicLabel(req.leaveType)} لمدّة ${req.numberOfDays} يوم. تسليم العمل إلى: ${req.workHandoverTo}.',
          data: {'leaveId': reqRef.id},
        );
      }
    } catch (_) {
      // The dispatcher can recover notification delivery from the committed
      // request without changing the employee-visible submission result.
    }
  }

  Future<void> cancelLeave(String leaveId, String userId) async {
    final ref = _db.collection('leaves').doc(leaveId);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) throw Exception('طلب الإجازة غير موجود.');
      final leave = LeaveModel.fromFirestore(doc);
      if (leave.userId != userId) throw Exception('غير مسموح بإلغاء الطلب.');
      if (!leave.status.startsWith('pending')) {
        throw Exception('لا يمكن إلغاء الطلب بعد صدور القرار النهائي.');
      }
      transaction.update(ref, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
      });
    });
  }

  Future<void> overrideCasualLeave({
    required String leaveId,
    required String reason,
  }) async {
    final auth = FirebaseAuth.instance;
    final token = await auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    }
    final operationId =
        List.generate(
          32,
          (_) =>
              'abcdefghijklmnopqrstuvwxyz0123456789'[DateTime.now()
                      .microsecondsSinceEpoch %
                  36],
        ).join();

    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse(
          'https://notification.zawolf.ai/operations/leaves/$leaveId/override-casual',
        ),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'operationId': operationId, 'reason': reason}),
      );
      final decoded =
          response.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(response.body);
      final data =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['ok'] != true) {
        throw StateError(
          '${data['error'] ?? 'تعذر تحويل الإجازة العارضة للمراجعة.'}',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> editCasualLeaveDates({
    required String leaveId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final auth = FirebaseAuth.instance;
    final token = await auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت الجلسة، سجل الدخول مرة أخرى.');
    }
    final operationId =
        List.generate(
          32,
          (_) =>
              'abcdefghijklmnopqrstuvwxyz0123456789'[DateTime.now()
                      .microsecondsSinceEpoch %
                  36],
        ).join();

    final startDateStr =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endDateStr =
        '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse(
          'https://notification.zawolf.ai/operations/leaves/$leaveId/edit-casual-dates',
        ),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'operationId': operationId,
          'startDate': startDateStr,
          'endDate': endDateStr,
          'reason': reason,
        }),
      );
      final decoded =
          response.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(response.body);
      final data =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['ok'] != true) {
        throw StateError(
          '${data['error'] ?? 'تعذر تعديل تاريخ الإجازة العارضة.'}',
        );
      }
    } finally {
      client.close();
    }
  }

  // Approve Leave
  Future<void> approveLeave(
    String leaveId,
    String reviewerId,
    String role,
  ) async {
    final docRef = _db.collection('leaves').doc(leaveId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإجازة غير موجود');
    final leave = LeaveModel.fromFirestore(doc);
    final data = doc.data() ?? <String, dynamic>{};
    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerName =
        (reviewerDoc.data()?['displayName'] as String?)?.trim() ?? '';
    final requiresCeoApproval =
        (data['requiresCeoApproval'] as bool?) ??
        LeaveTypePolicy.requiresCeoApproval(
          leave.leaveType,
          leave.numberOfDays,
        );

    if (leave.status == 'pending_ceo') {
      final reviewerCode =
          (reviewerDoc.data()?['employeeId'] as String?)?.trim() ?? '';
      if (!reviewerCode.toUpperCase().startsWith('CEO-') ||
          data['ceoId'] != reviewerId) {
        throw Exception('هذه المرحلة متاحة للـ CEO المعيّن للموظف فقط.');
      }
      final event = _approvalEvent(
        stage: 'ceo',
        status: 'approved',
        actorId: reviewerId,
        actorName: reviewerName,
      );
      await docRef.update({
        'status': 'pending_hr',
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': FieldValue.serverTimestamp(),
        'approvalHistory': FieldValue.arrayUnion([event]),
      });
      try {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrAdmin,
          includeSuperAdmins: false,
          type: 'leave_request_submitted',
          title: 'إجازة طويلة بانتظار مراجعة HR',
          body:
              'اعتمد CEO المعيّن طلب ${leave.employeeName} وهو الآن بانتظار القرار النهائي من HR.',
          data: {'leaveId': leaveId},
        );
      } catch (_) {
        // Notification retry is independent of committed decision
      }
      return;
    }

    if (leave.status == 'pending_hr') {
      final requesterDoc =
          await _db.collection('users').doc(leave.userId).get();
      final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
      if (leave.userId == reviewerId) {
        throw Exception('لا يمكن اعتماد طلبك الشخصي. يجب أن يراجعه HR آخر.');
      }
      if (!EmployeeRole.isHr(role)) {
        throw Exception('هذه المرحلة يراجعها HR فقط.');
      }
      final managerIds =
          (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      if (managerIds.isEmpty &&
          requesterRole == EmployeeRole.superAdmin &&
          role != EmployeeRole.hrManager) {
        throw Exception('الطلبات بدون مدير معيّن يراجعها HR فقط.');
      }
      if (requesterRole == EmployeeRole.superAdmin &&
          role != EmployeeRole.hrAdmin &&
          role != EmployeeRole.hrManager) {
        throw Exception('طلبات مالك النظام يراجعها HR فقط.');
      }
    }

    final batch = _db.batch();

    bool isFinalApproval = false;
    Map<String, dynamic> update;

    if (EmployeeRole.isHr(role)) {
      if (leave.status == 'pending_hr') {
        final managerIds =
            (data['managerIds'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            (leave.managerId.isEmpty ? <String>[] : <String>[leave.managerId]);
        final managerNames =
            (data['managerNames'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            <String>[];
        final approvalTrail =
            (data['managerApprovalTrail'] as List<dynamic>?) ?? <dynamic>[];
        final managersCompleted =
            managerIds.isEmpty || approvalTrail.length >= managerIds.length;
        final firstManagerId = managerIds.isNotEmpty ? managerIds.first : '';
        final nextStatus =
            requiresCeoApproval
                ? 'pending_ceo'
                : (managersCompleted ? 'approved' : 'pending_manager');
        update = {
          'status': nextStatus,
          if (!managersCompleted && firstManagerId.isNotEmpty)
            'managerId': firstManagerId,
          if (!managersCompleted && managerNames.isNotEmpty)
            'managerName': managerNames.first,
          if (!managersCompleted) 'managerApprovalIndex': 0,
          'reviewedBy': reviewerId,
          'reviewerName': reviewerName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'approvalHistory': FieldValue.arrayUnion([
            _approvalEvent(
              stage: 'hr',
              status: 'approved',
              actorId: reviewerId,
              actorName: reviewerName,
            ),
          ]),
        };
        isFinalApproval = nextStatus == 'approved';
      } else {
        if (leave.managerId != reviewerId && role != EmployeeRole.superAdmin) {
          throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
        }
        update = _nextManagerApprovalUpdate(
          data: data,
          reviewerId: reviewerId,
          reviewerRole: role,
          reviewerName: reviewerName,
        );
        isFinalApproval = update['status'] == 'approved';
      }
    } else {
      // Manager
      if (leave.managerId != reviewerId) {
        throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
      }
      update = _nextManagerApprovalUpdate(
        data: data,
        reviewerId: reviewerId,
        reviewerRole: role,
        reviewerName: reviewerName,
      );
      isFinalApproval = update['status'] == 'approved';
    }

    update['reviewerName'] = reviewerName;

    batch.update(docRef, update);

    if (isFinalApproval) {
      // Deduct leave balance
      final balanceKeys =
          leave.leaveType == LeaveTypePolicy.sick && leave.convertToAnnual
              ? const <String>['annual', 'daysOff']
              : LeaveTypePolicy.balanceKeys(leave.leaveType);

      final userRef = _db.collection('users').doc(leave.userId);
      if (balanceKeys.isNotEmpty) {
        final userSnapshot = await userRef.get();
        if (!userSnapshot.exists) throw Exception('حساب الموظف غير موجود.');
        final balance = UserModel.fromFirestore(userSnapshot).leaveBalance;
        if (leave.leaveType == LeaveTypePolicy.sick &&
            leave.convertToAnnual &&
            leave.numberOfDays > balance.daysOff) {
          throw Exception(
            'رصيد الإجازات الكلي غير كافٍ لتحويل الإجازة المرضية.',
          );
        }
        validateBalance(leave, balance);
        batch.update(userRef, {
          for (final key in balanceKeys)
            'leaveBalance.$key': FieldValue.increment(-leave.numberOfDays),
        });
      }
    }

    await batch.commit();

    // The approval is committed above. Audit/notification/reconciliation are
    // follow-up work and must never make the UI report a failed approval after
    // the leave was already saved. That previously led reviewers to retry and
    // create duplicate approval history entries.
    try {
      await AuditLogService.instance.record(
        actorId: reviewerId,
        action: 'leave_approved',
        targetCollection: 'leaves',
        targetId: leaveId,
        metadata: {
          'userId': leave.userId,
          'numberOfDays': leave.numberOfDays,
          'leaveType': leave.leaveType,
        },
      );
    } catch (_) {}

    if (update['status'] == 'pending_manager') {
      final nextManagerId = update['managerId'] as String?;
      if (nextManagerId != null && nextManagerId.isNotEmpty) {
        try {
          await _createNotification(
            recipientId: nextManagerId,
            type: 'leave_request_submitted',
            title: 'طلب إجازة بانتظار موافقتك',
            body: '${leave.employeeName} حصل على موافقة سابقة وينتظر قرارك.',
            data: {'leaveId': leaveId},
          );
        } catch (_) {}
      }
      return;
    }

    if (update['status'] == 'pending_hr') {
      try {
        await RoleNotificationService.instance.notifyRole(
          role: EmployeeRole.hrAdmin,
          includeSuperAdmins: false,
          type: 'leave_request_submitted',
          title: 'طلب إجازة بانتظار مراجعة HR',
          body:
              'اكتملت موافقات المديرين على طلب ${leave.employeeName} وينتظر القرار النهائي من HR.',
          data: {'leaveId': leaveId},
        );
      } catch (_) {
        // The decision was committed above; notification retry is independent.
      }
      return;
    }

    if (update['status'] == 'pending_ceo') {
      final ceoId = data['ceoId'] as String?;
      if (ceoId == null || ceoId.isEmpty) {
        throw Exception('تعذر تحديد CEO المعيّن للموظف.');
      }
      try {
        await _createNotification(
          recipientId: ceoId,
          type: 'leave_request_submitted',
          title: 'إجازة طويلة بانتظار اعتماد CEO',
          body:
              'راجع HR طلب ${leave.employeeName} لمدة ${leave.numberOfDays} أيام وينتظر اعتمادك النهائي.',
          data: {'leaveId': leaveId},
        );
      } catch (_) {
        // Never make HR repeat a saved decision because a push is delayed.
      }
      return;
    }

    // 3. Notify employee
    try {
      await _reconciliationService.reconcileApprovedLeave(leave);
    } catch (_) {}
    try {
      await _createNotification(
        recipientId: leave.userId,
        type: 'leave_approved',
        title: 'تم قبول طلب الإجازة ✅',
        body:
            'تمت الموافقة على طلب إجازتك لمدّة ${leave.numberOfDays} يوم. السبب المسجل: ${leave.reason}',
        data: {
          'leaveId': leaveId,
          'route': '/employee/requests',
          'decision': 'approved',
          'resyncAttendanceAlarm': true,
        },
      );
    } catch (_) {}
  }

  // Reject Leave
  Future<void> rejectLeave(
    String leaveId,
    String reviewerId,
    String comment,
  ) async {
    final docRef = _db.collection('leaves').doc(leaveId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإجازة غير موجود');
    final leave = LeaveModel.fromFirestore(doc);
    final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
    final reviewerRole = reviewerDoc.data()?['role'] as String? ?? '';
    final reviewerName =
        (reviewerDoc.data()?['displayName'] as String?)?.trim() ?? '';
    if (leave.status == 'pending_ceo') {
      final reviewerCode =
          (reviewerDoc.data()?['employeeId'] as String?)?.trim() ?? '';
      if (reviewerCode != 'CEO-100') {
        throw Exception('رفض هذا الطلب متاح لحساب CEO-100 فقط.');
      }
    }
    if (leave.status == 'pending_hr') {
      final requesterDoc =
          await _db.collection('users').doc(leave.userId).get();
      final requesterRole = requesterDoc.data()?['role'] as String? ?? '';
      if (leave.userId == reviewerId) {
        throw Exception('لا يمكن رفض طلبك الشخصي. يجب أن يراجعه HR آخر.');
      }
      if (!EmployeeRole.isHr(reviewerRole)) {
        throw Exception('هذه المرحلة يراجعها HR فقط.');
      }
      final managerIds =
          (doc.data()?['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      if (managerIds.isEmpty &&
          requesterRole == EmployeeRole.superAdmin &&
          reviewerRole != EmployeeRole.hrManager) {
        throw Exception('الطلبات بدون مدير معيّن يراجعها HR فقط.');
      }
      if (requesterRole == EmployeeRole.superAdmin &&
          reviewerRole != EmployeeRole.hrAdmin &&
          reviewerRole != EmployeeRole.hrManager) {
        throw Exception('طلبات مالك النظام يراجعها HR فقط.');
      }
    }
    if (leave.status == 'pending_manager' &&
        leave.managerId != reviewerId &&
        reviewerRole != EmployeeRole.superAdmin) {
      throw Exception('هذا الطلب ينتظر قرار مدير آخر.');
    }

    await docRef.update({
      'status': 'rejected',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerComment': comment,
      'reviewerName': reviewerName,
      'finalApproverId': reviewerId,
      'finalApproverName': reviewerName,
      'finalApprovalAt': FieldValue.serverTimestamp(),
      'approvalHistory': FieldValue.arrayUnion([
        _approvalEvent(
          stage:
              leave.status == 'pending_ceo'
                  ? 'ceo'
                  : leave.status == 'pending_hr'
                  ? 'hr'
                  : 'manager',
          status: 'rejected',
          actorId: reviewerId,
          actorName: reviewerName,
          comment: comment,
        ),
      ]),
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'leave_rejected',
      targetCollection: 'leaves',
      targetId: leaveId,
      metadata: {'userId': leave.userId, 'leaveType': leave.leaveType},
    );

    // Notify employee
    try {
      await _createNotification(
        recipientId: leave.userId,
        type: 'leave_rejected',
        title: 'تم رفض طلب الإجازة ❌',
        body: 'تم رفض طلب إجازتك. السبب: $comment',
        data: {
          'leaveId': leaveId,
          'route': '/employee/requests',
          'decision': 'rejected',
          'decisionReason': comment,
          'resyncAttendanceAlarm': true,
        },
      );
    } catch (_) {}
  }

  // Private Helper to create notification records
  Future<void> _createNotification({
    required String recipientId,
    String? notificationId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await RoleNotificationService.instance.createNotification(
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      data: data,
      eventId: notificationId,
    );
  }
}
