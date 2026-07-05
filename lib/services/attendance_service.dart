import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_policy.dart';
import 'attendance_security_service.dart';
import 'attendance_policy_service.dart';
import 'audit_log_service.dart';
import 'company_day_off_service.dart';
import 'geofence_service.dart';
import 'offline_attendance_queue_service.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GeofenceService _geofenceService = GeofenceService();
  final AttendanceSecurityService _securityService =
      AttendanceSecurityService();
  final AttendancePolicyService _policyService = AttendancePolicyService();
  final CompanyDayOffService _dayOffService = CompanyDayOffService();
  final OfflineAttendanceQueueService _offlineQueue =
      OfflineAttendanceQueueService.instance;

  // Handle employee Check-In or Check-Out
  Future<void> handleCheckInOrCheckOut(UserModel employee) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final online = await _offlineQueue.isOnline();
    final policyConfig = await _policyService.getPolicyConfig();

    if (online) {
      await _offlineQueue.syncPendingActions();
      await _flagMissedCheckouts(employee, todayStr);
    }

    final todayLookup = await _loadTodayAttendance(employee.uid, todayStr);
    final isCheckIn = todayLookup.log == null;
    if (isCheckIn) {
      final dayOffStatus = await _dayOffService.getDayOffStatus(now);
      if (dayOffStatus.isDayOff) {
        throw Exception('تسجيل الحضور غير متاح اليوم: ${dayOffStatus.reason}.');
      }
    }

    // 1. Validate employee position against assigned branch's geofence
    final geoResult = await _geofenceService.validateCheckIn(employee);

    if (!geoResult.isWithinZone) {
      throw Exception(
        '🐺 أنت خارج نطاق العمل المسموح به لفرع (${geoResult.locationName}).\n'
        'المسافة الحالية: ${geoResult.distanceMeters.toInt()} متر.\n'
        'النطاق المسموح به: ${geoResult.allowedRadius.toInt()} متر.',
      );
    }

    // Check if spoofing app is used
    if (geoResult.isMocked) {
      throw Exception(
        'عذراً، تم الكشف عن استخدام تطبيق لتزييف الموقع الجغرافي (Mock GPS).',
      );
    }

    final securityResult = await _securityService.verifyForAttendance();
    await _ensureAttendanceDeviceBinding(
      employee,
      securityResult,
      allowOfflineFallback: !online,
    );

    if (isCheckIn) {
      // ── CHECK-IN LOGIC ──
      final companyStartTimeStr =
          employee.workSchedule.startTime ?? policyConfig.defaultStartTime;
      final deduction = policyConfig.evaluateLateArrival(
        arrivalTime: now,
        employeeStartTime: companyStartTimeStr,
      );
      final salaryDeductionAmount = policyConfig.calculateSalaryDeductionAmount(
        monthlySalary: employee.baseMonthlySalary,
        dayFraction: deduction.dayFraction,
      );

      final logRef = _db
          .collection('attendance')
          .doc('${employee.uid}_$todayStr');
      final offlineAction = OfflineAttendanceAction(
        id: '${logRef.id}_checkIn',
        type: OfflineAttendanceActionType.checkIn,
        attendanceId: logRef.id,
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        locationId: employee.locationId,
        locationName: employee.locationName,
        managerId: employee.managerId,
        date: todayStr,
        eventTime: now,
        latitude: geoResult.position.latitude,
        longitude: geoResult.position.longitude,
        distanceMeters: geoResult.distanceMeters,
        allowedRadius: geoResult.allowedRadius,
        accuracyMeters: geoResult.accuracyMeters,
        deviceId: securityResult.deviceId,
        deviceLabel: securityResult.deviceLabel,
        isLate: deduction.isLate,
        lateMinutes: deduction.lateMinutes,
        salaryDeductionFraction: deduction.dayFraction,
        salaryDeductionAmount: salaryDeductionAmount,
        salaryCurrency: employee.salaryCurrency,
        salaryDeductionCode: deduction.code,
        salaryDeductionLabel: deduction.arabicLabel,
        salaryDeductionApprovalStatus: deduction.dayFraction > 0
            ? 'pending_hr'
            : 'none',
        status: deduction.status,
      );
      final attendanceLog = AttendanceModel(
        attendanceId: logRef.id,
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        locationId: employee.locationId,
        locationName: employee.locationName,
        managerId: employee.managerId,
        date: todayStr,
        checkInTime: now,
        checkInLocation: GeoPoint(
          geoResult.position.latitude,
          geoResult.position.longitude,
        ),
        localCheckInTime: now,
        isWithinGeofence: true,
        isLate: deduction.isLate,
        lateMinutes: deduction.lateMinutes,
        salaryDeductionFraction: deduction.dayFraction,
        salaryDeductionAmount: salaryDeductionAmount,
        salaryCurrency: employee.salaryCurrency,
        salaryDeductionCode: deduction.code,
        salaryDeductionLabel: deduction.arabicLabel,
        salaryDeductionApprovalStatus: deduction.dayFraction > 0
            ? 'pending_hr'
            : 'none',
        deviceId: securityResult.deviceId,
        deviceLabel: securityResult.deviceLabel,
        biometricVerified: securityResult.biometricOrDeviceCredentialVerified,
        status: deduction.status,
      );

      if (online) {
        await logRef.set(attendanceLog.toFirestore());
      } else {
        await _offlineQueue.queue(offlineAction);
      }
      if (online && deduction.dayFraction > 0) {
        await _notifyRole(
          role: 'hr_admin',
          type: 'salary_deduction_pending',
          title: 'خصم تأخير بانتظار مراجعة HR',
          body:
              '${employee.displayName}: ${deduction.arabicLabel} (${salaryDeductionAmount.toStringAsFixed(2)} ${employee.salaryCurrency}).',
          data: {'attendanceId': logRef.id},
        );
      }
    } else {
      // ── CHECK-OUT LOGIC ──
      final checkInDoc = todayLookup.doc;
      final checkInLog = todayLookup.log!;

      if (checkInLog.checkOutTime != null) {
        throw Exception('لقد قمت بتسجيل الانصراف بالفعل لهذا اليوم.');
      }

      final checkInTime = checkInLog.checkInTime ?? now;
      final totalWorkHours = now.difference(checkInTime).inMinutes / 60.0;
      final earlyCheckoutDeduction = _buildCheckoutDeductionPatch(
        employee: employee,
        currentLog: checkInLog,
        reasonCode: 'early_checkout_quarter_day',
        reasonLabel: 'خصم ربع يوم - انصراف مبكر',
        now: now,
        applies: _isEarlyCheckout(
          now,
          employee.workSchedule.endTime ?? policyConfig.defaultEndTime,
        ),
        payrollWorkDaysPerMonth: policyConfig.payrollWorkDaysPerMonth,
      );
      final offlineAction = OfflineAttendanceAction(
        id: '${checkInLog.attendanceId}_checkOut',
        type: OfflineAttendanceActionType.checkOut,
        attendanceId: checkInLog.attendanceId,
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        locationId: employee.locationId,
        locationName: employee.locationName,
        managerId: employee.managerId,
        date: todayStr,
        eventTime: now,
        latitude: geoResult.position.latitude,
        longitude: geoResult.position.longitude,
        distanceMeters: geoResult.distanceMeters,
        allowedRadius: geoResult.allowedRadius,
        accuracyMeters: geoResult.accuracyMeters,
        deviceId: securityResult.deviceId,
        deviceLabel: securityResult.deviceLabel,
        totalWorkHours: totalWorkHours,
        isLate: checkInLog.isLate,
        lateMinutes: checkInLog.lateMinutes,
        salaryDeductionFraction: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionFraction
            : 0.25,
        salaryDeductionAmount: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionAmount
            : earlyCheckoutDeduction.amount,
        salaryCurrency: employee.salaryCurrency,
        salaryDeductionCode: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionCode
            : 'early_checkout_quarter_day',
        salaryDeductionLabel: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionLabel
            : earlyCheckoutDeduction.label,
        salaryDeductionApprovalStatus: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionApprovalStatus
            : 'pending_hr',
        status: checkInLog.status,
      );

      if (online && checkInDoc != null) {
        await checkInDoc.reference.update({
          'checkOutTime': Timestamp.fromDate(now),
          'checkOutLocation': GeoPoint(
            geoResult.position.latitude,
            geoResult.position.longitude,
          ),
          'localCheckOutTime': Timestamp.fromDate(now),
          'totalWorkHours': totalWorkHours,
          'checkOutDeviceId': securityResult.deviceId,
          'checkOutDeviceLabel': securityResult.deviceLabel,
          'checkOutBiometricVerified':
              securityResult.biometricOrDeviceCredentialVerified,
          ...earlyCheckoutDeduction.patch,
        });
      } else {
        await _offlineQueue.queue(offlineAction);
      }

      if (online && earlyCheckoutDeduction.shouldNotify) {
        await _notifyRole(
          role: 'hr_admin',
          type: 'salary_deduction_pending',
          title: 'خصم انصراف مبكر بانتظار مراجعة HR',
          body:
              '${employee.displayName}: ${earlyCheckoutDeduction.label} (${earlyCheckoutDeduction.amount.toStringAsFixed(2)} ${employee.salaryCurrency}).',
          data: {'attendanceId': checkInDoc?.id ?? checkInLog.attendanceId},
        );
      }
    }
  }

  Future<void> syncPendingOfflineAttendance() {
    return _offlineQueue.syncPendingActions();
  }

  Future<AttendanceModel?> loadTodayAttendanceForDisplay(String userId) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return (await _loadTodayAttendance(userId, todayStr)).log;
  }

  Future<_TodayAttendanceLookup> _loadTodayAttendance(
    String userId,
    String todayStr,
  ) async {
    try {
      final existingLogs = await _db
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get();
      if (existingLogs.docs.isNotEmpty) {
        final doc = existingLogs.docs.first;
        return _TodayAttendanceLookup(
          doc: doc,
          log: AttendanceModel.fromFirestore(doc),
        );
      }
    } catch (_) {
      try {
        final cachedLogs = await _db
            .collection('attendance')
            .where('userId', isEqualTo: userId)
            .where('date', isEqualTo: todayStr)
            .limit(1)
            .get(const GetOptions(source: Source.cache));
        if (cachedLogs.docs.isNotEmpty) {
          final doc = cachedLogs.docs.first;
          return _TodayAttendanceLookup(
            doc: doc,
            log: AttendanceModel.fromFirestore(doc),
          );
        }
      } catch (_) {}
    }

    final monthKey = todayStr.substring(0, 7);
    final pending = await _offlineQueue.pendingLogsForMonth(
      userId: userId,
      monthKey: monthKey,
    );
    for (final log in pending) {
      if (log.date == todayStr) {
        return _TodayAttendanceLookup(log: log);
      }
    }
    return const _TodayAttendanceLookup();
  }

  Future<void> _ensureAttendanceDeviceBinding(
    UserModel employee,
    AttendanceSecurityResult securityResult, {
    required bool allowOfflineFallback,
  }) async {
    final deviceId = securityResult.deviceId.trim();
    if (deviceId.isEmpty) {
      throw Exception('تعذر قراءة رقم الجهاز. أعد المحاولة أو تواصل مع HR.');
    }

    final localOwner = await _offlineQueue.localDeviceOwner(deviceId);
    if (localOwner != null && localOwner != employee.uid) {
      throw Exception(
        'هذا الجهاز مربوط محلياً بحساب موظف آخر. لا يمكن تسجيل حضور أكثر من حساب من نفس الجهاز.',
      );
    }

    final locallyRegisteredDevice =
        employee.registeredAttendanceDeviceId?.trim() ?? '';
    if (locallyRegisteredDevice.isNotEmpty) {
      if (locallyRegisteredDevice == deviceId) {
        await _offlineQueue.rememberLocalDeviceOwner(
          deviceId: deviceId,
          userId: employee.uid,
        );
        return;
      }
      throw Exception(
        'هذا الحساب مربوط بجهاز حضور آخر. اطلب من HR إعادة ضبط جهاز الحضور قبل استخدام هذا الجهاز.',
      );
    }

    if (allowOfflineFallback && !await _offlineQueue.isOnline()) {
      await _offlineQueue.rememberLocalDeviceOwner(
        deviceId: deviceId,
        userId: employee.uid,
      );
      return;
    }

    final userRef = _db.collection('users').doc(employee.uid);
    final deviceRef = _db
        .collection('attendanceDevices')
        .doc(AttendanceSecurityService.deviceDocumentId(deviceId));

    try {
      await _db.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw Exception('لم يتم العثور على حساب الموظف.');
        }

        final userData = userSnap.data() ?? <String, dynamic>{};
        final registeredDeviceId =
            (userData['registeredAttendanceDeviceId'] as String?)?.trim() ?? '';

        if (registeredDeviceId.isNotEmpty) {
          if (registeredDeviceId != deviceId) {
            throw Exception(
              'هذا الحساب مربوط بجهاز حضور آخر. اطلب من HR إعادة ضبط جهاز الحضور قبل استخدام هذا الجهاز.',
            );
          }
          return;
        }

        final deviceSnap = await transaction.get(deviceRef);
        if (deviceSnap.exists) {
          final deviceData = deviceSnap.data() ?? <String, dynamic>{};
          final boundUserId = deviceData['userId'] as String? ?? '';
          if (boundUserId != employee.uid) {
            throw Exception(
              'هذا الجهاز مربوط بحساب موظف آخر. لا يمكن تسجيل حضور أكثر من حساب من نفس الجهاز.',
            );
          }
        } else {
          transaction.set(deviceRef, {
            'deviceId': deviceId,
            'userId': employee.uid,
            'employeeId': employee.employeeId,
            'employeeName': employee.displayName,
            'deviceLabel': securityResult.deviceLabel,
            'registeredAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(userRef, {
          'registeredAttendanceDeviceId': deviceId,
          'registeredAttendanceDeviceLabel': securityResult.deviceLabel,
          'registeredAttendanceDeviceAt': FieldValue.serverTimestamp(),
        });
      });

      await _offlineQueue.rememberLocalDeviceOwner(
        deviceId: deviceId,
        userId: employee.uid,
      );
    } catch (e) {
      if (!allowOfflineFallback) rethrow;
      await _offlineQueue.rememberLocalDeviceOwner(
        deviceId: deviceId,
        userId: employee.uid,
      );
    }
  }

  bool _isEarlyCheckout(DateTime now, String? configuredEndTime) {
    final endTime = configuredEndTime ?? AttendancePolicy.defaultEndTime;
    final shiftEnd = AttendancePolicy.parseTimeOnDate(now, endTime);
    return now.isBefore(shiftEnd);
  }

  Future<void> _flagMissedCheckouts(UserModel employee, String todayStr) async {
    final snapshot = await _db
        .collection('attendance')
        .where('userId', isEqualTo: employee.uid)
        .where('date', isLessThan: todayStr)
        .limit(10)
        .get();

    for (final doc in snapshot.docs) {
      final log = AttendanceModel.fromFirestore(doc);
      if (log.checkOutTime != null) continue;

      final missedCheckoutDeduction = _buildCheckoutDeductionPatch(
        employee: employee,
        currentLog: log,
        reasonCode: 'missed_checkout_quarter_day',
        reasonLabel: 'خصم ربع يوم - عدم تسجيل الانصراف',
        now: DateTime.now(),
        applies: true,
      );
      if (missedCheckoutDeduction.patch.isEmpty) continue;

      await doc.reference.update(missedCheckoutDeduction.patch);

      if (missedCheckoutDeduction.shouldNotify) {
        await _notifyRole(
          role: 'hr_admin',
          type: 'salary_deduction_pending',
          title: 'خصم عدم تسجيل انصراف بانتظار مراجعة HR',
          body:
              '${employee.displayName}: ${missedCheckoutDeduction.label} عن يوم ${log.date} (${missedCheckoutDeduction.amount.toStringAsFixed(2)} ${employee.salaryCurrency}).',
          data: {'attendanceId': doc.id},
        );
      }
    }
  }

  _DeductionPatch _buildCheckoutDeductionPatch({
    required UserModel employee,
    required AttendanceModel currentLog,
    required String reasonCode,
    required String reasonLabel,
    required DateTime now,
    required bool applies,
    int payrollWorkDaysPerMonth =
        AttendancePolicy.defaultPayrollWorkDaysPerMonth,
  }) {
    if (!applies || currentLog.salaryDeductionFraction >= 0.25) {
      return const _DeductionPatch.empty();
    }

    final amount = AttendancePolicy.calculateSalaryDeductionAmount(
      monthlySalary: employee.baseMonthlySalary,
      dayFraction: 0.25,
      payrollWorkDaysPerMonth: payrollWorkDaysPerMonth,
    );

    return _DeductionPatch(
      patch: {
        'salaryDeductionFraction': 0.25,
        'salaryDeductionAmount': amount,
        'salaryCurrency': employee.salaryCurrency,
        'salaryDeductionCode': reasonCode,
        'salaryDeductionLabel': reasonLabel,
        'salaryDeductionApprovalStatus': 'pending_hr',
        'salaryDeductionDetectedAt': Timestamp.fromDate(now),
      },
      shouldNotify: currentLog.salaryDeductionApprovalStatus != 'pending_hr',
      label: reasonLabel,
      amount: amount,
    );
  }

  // Stream current month's attendance records for employee
  Stream<List<AttendanceModel>> watchMonthlyAttendance(
    String userId,
    String monthKey,
  ) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final nextMonthStr = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    final remoteStream = _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: '$monthKey-01')
        .where('date', isLessThan: nextMonthStr)
        .snapshots();

    return Stream.multi((controller) {
      var remoteLogs = <AttendanceModel>[];

      Future<void> emitMerged() async {
        final pendingLogs = await _offlineQueue.pendingLogsForMonth(
          userId: userId,
          monthKey: monthKey,
        );
        final merged = <String, AttendanceModel>{
          for (final log in remoteLogs) log.attendanceId: log,
        };
        for (final pending in pendingLogs) {
          merged[pending.attendanceId] = pending;
        }
        final logs = merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        if (!controller.isClosed) controller.add(logs);
      }

      final remoteSub = remoteStream.listen((snapshot) {
        remoteLogs = snapshot.docs
            .map((doc) => AttendanceModel.fromFirestore(doc))
            .toList();
        emitMerged();
      }, onError: controller.addError);
      final pendingSub = _offlineQueue.changes.listen((_) => emitMerged());
      emitMerged();

      controller.onCancel = () async {
        await remoteSub.cancel();
        await pendingSub.cancel();
      };
    });
  }

  // Stream team's attendance records for manager
  Stream<List<AttendanceModel>> watchTeamAttendanceToday(
    String managerId,
    String todayStr,
  ) {
    return _db
        .collection('attendance')
        .where('managerId', isEqualTo: managerId)
        .where('date', isEqualTo: todayStr)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AttendanceModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> approveSalaryDeduction(
    String attendanceId,
    String reviewerId,
  ) async {
    await _reviewSalaryDeduction(attendanceId, reviewerId, 'approved');
  }

  Future<void> rejectSalaryDeduction(
    String attendanceId,
    String reviewerId,
  ) async {
    await _reviewSalaryDeduction(attendanceId, reviewerId, 'rejected');
  }

  Future<void> _reviewSalaryDeduction(
    String attendanceId,
    String reviewerId,
    String status,
  ) async {
    await _db.collection('attendance').doc(attendanceId).update({
      'salaryDeductionApprovalStatus': status,
      'salaryDeductionReviewedBy': reviewerId,
      'salaryDeductionReviewedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'salary_deduction_$status',
      targetCollection: 'attendance',
      targetId: attendanceId,
    );

    // Get attendance doc to find employee ID
    final doc = await _db.collection('attendance').doc(attendanceId).get();
    if (doc.exists) {
      final userId = doc.data()?['userId'] as String?;
      if (userId != null) {
        final notifRef = _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .doc();

        final title = status == 'approved'
            ? 'تم اعتماد الخصم'
            : 'تم إلغاء الخصم';
        final body = status == 'approved'
            ? 'تم اعتماد خصم الحضور والانصراف الخاص بك.'
            : 'تم إلغاء خصم الحضور والانصراف الخاص بك.';

        await notifRef.set({
          'notificationId': notifRef.id,
          'type': 'salary_deduction_reviewed',
          'title': title,
          'body': body,
          'data': {'attendanceId': attendanceId},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _db.collection('users').doc(userId).update({
          'unreadNotifications': FieldValue.increment(1),
        });
      }
    }
  }

  Future<void> _notifyRole({
    required String role,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final targets = <String>{};
      final roleSnap = await _db
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      targets.addAll(roleSnap.docs.map((doc) => doc.id));
      final superSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'super_admin')
          .get();
      targets.addAll(superSnap.docs.map((doc) => doc.id));

      for (final userId in targets) {
        final notifRef = _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .doc();
        await notifRef.set({
          'notificationId': notifRef.id,
          'type': type,
          'title': title,
          'body': body,
          'data': data ?? {},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _db.collection('users').doc(userId).update({
          'unreadNotifications': FieldValue.increment(1),
        });
      }
    } catch (_) {
      // Notification delivery must never make attendance fail.
    }
  }
}

class _DeductionPatch {
  final Map<String, dynamic> patch;
  final bool shouldNotify;
  final String label;
  final double amount;

  const _DeductionPatch({
    required this.patch,
    required this.shouldNotify,
    required this.label,
    required this.amount,
  });

  const _DeductionPatch.empty()
    : patch = const {},
      shouldNotify = false,
      label = '',
      amount = 0;
}

class _TodayAttendanceLookup {
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;
  final AttendanceModel? log;

  const _TodayAttendanceLookup({this.doc, this.log});
}
