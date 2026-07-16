import 'dart:async';

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
import 'field_assignment_service.dart';
import 'offline_attendance_queue_service.dart';
import 'role_notification_service.dart';

enum AttendanceActionIntent { checkIn, checkOut }

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GeofenceService _geofenceService = GeofenceService();
  final AttendanceSecurityService _securityService =
      AttendanceSecurityService();
  final AttendancePolicyService _policyService = AttendancePolicyService();
  final CompanyDayOffService _dayOffService = CompanyDayOffService();
  final FieldAssignmentService _fieldAssignmentService =
      FieldAssignmentService();
  final OfflineAttendanceQueueService _offlineQueue =
      OfflineAttendanceQueueService.instance;

  // Handle employee Check-In or Check-Out
  Future<void> handleCheckInOrCheckOut(
    UserModel employee, {
    AttendanceActionIntent? expectedAction,
  }) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final online = await _offlineQueue.isOnline();
    final policyConfig = await _policyService.getPolicyConfig();
    final requiresLiveConnection = !policyConfig.requiresBiometric;

    if (requiresLiveConnection && !online) {
      throw Exception(
        'تسجيل الحضور بالموقع فقط يتطلب اتصالاً بالإنترنت للتحقق من الوقت والموقع مباشرة. اتصل بالإنترنت ثم أعد المحاولة.',
      );
    }

    if (online) {
      try {
        await _offlineQueue.syncPendingActions();
        await _flagMissedCheckouts(employee, todayStr);
      } catch (error) {
        // Connectivity can be present while Firestore is temporarily
        // unavailable. Do not prevent a new verified attendance action.
        if (!_isTemporaryFirestoreFailure(error)) rethrow;
      }
    }

    final todayLookup = await _loadTodayAttendance(employee.uid, todayStr);
    final isCheckIn = todayLookup.log?.checkInTime == null;
    final actualAction = isCheckIn
        ? AttendanceActionIntent.checkIn
        : AttendanceActionIntent.checkOut;

    if (expectedAction != null && expectedAction != actualAction) {
      if (expectedAction == AttendanceActionIntent.checkIn) {
        throw Exception(
          'يوجد تسجيل حضور محفوظ لهذا اليوم. قم بتحديث الصفحة، وسيظهر زر الانصراف في موعده.',
        );
      }
      throw Exception(
        'لا يوجد تسجيل حضور صالح لهذا اليوم. اضغط تسجيل حضور أولاً.',
      );
    }

    if (isCheckIn) {
      final checkInOpenAt = AttendancePolicy.parseTimeOnDate(
        now,
        policyConfig.checkInOpenTime,
      );
      if (now.isBefore(checkInOpenAt)) {
        throw Exception(
          'تسجيل الحضور يفتح من الساعة ${_formatArabicTime(checkInOpenAt)}.',
        );
      }

      final dayOffStatus = await _dayOffService.getDayOffStatus(now);
      if (dayOffStatus.isDayOff) {
        throw Exception('تسجيل الحضور غير متاح اليوم: ${dayOffStatus.reason}.');
      }
    } else {
      final checkInLog = todayLookup.log!;
      if (checkInLog.checkOutTime != null) {
        throw Exception('لقد قمت بتسجيل الانصراف بالفعل لهذا اليوم.');
      }

      final allowedCheckoutFrom = await _effectiveCheckoutAllowedFrom(
        employee: employee,
        dateKey: todayStr,
        policyConfig: policyConfig,
        now: now,
      );
      final latestCheckoutAt = AttendancePolicy.parseTimeOnDate(
        now,
        policyConfig.latestCheckoutTime,
      );

      if (now.isBefore(allowedCheckoutFrom)) {
        throw Exception(
          'تسجيل الانصراف يفتح من الساعة ${_formatArabicTime(allowedCheckoutFrom)}.',
        );
      }
      if (now.isAfter(latestCheckoutAt)) {
        throw Exception(
          'انتهت مهلة تسجيل الانصراف لهذا اليوم عند الساعة ${_formatArabicTime(latestCheckoutAt)}. سيتم إرسال عدم تسجيل الانصراف إلى HR للمراجعة.',
        );
      }
    }

    // An active HR-created field assignment is a time-bounded, auditable
    // exception to branch geofence enforcement.
    final activeFieldAssignment = await _fieldAssignmentService.activeAt(
      userId: employee.uid,
      dateKey: todayStr,
      now: now,
    );

    // Check if employee has an approved WFH request today
    final wfhQuery = await _db
        .collection('leaves')
        .where('userId', isEqualTo: employee.uid)
        .where('leaveType', isEqualTo: 'wfh')
        .where('status', isEqualTo: 'approved')
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    final hasWfhToday = wfhQuery.docs.any((doc) {
      final data = doc.data();
      final end = (data['endDate'] as Timestamp).toDate();
      // If now is before end of that day (23:59)
      return now.isBefore(end.add(const Duration(days: 1)));
    });

    // 1. Validate employee position against assigned branch's geofence
    final geoResult = await _geofenceService.validateCheckIn(
      employee,
      strictLocationOnly: requiresLiveConnection,
    );

    final allowsExternalWork = hasWfhToday || activeFieldAssignment != null;
    if (!geoResult.isWithinZone && !allowsExternalWork) {
      throw Exception(
        '🐺 أنت خارج نطاق العمل المسموح به لفرع (${geoResult.locationName}).\n'
        'المسافة الحالية: ${geoResult.distanceMeters.toInt()} متر.\n'
        'النطاق المسموح به: ${geoResult.allowedRadius.toInt()} متر.',
      );
    }

    // Check if spoofing app is used
    // A valid WFH or field assignment changes the allowed place, never the
    // requirement for a genuine device location.
    if (geoResult.isMocked) {
      throw Exception(
        'عذراً، تم الكشف عن استخدام تطبيق لتزييف الموقع الجغرافي (Mock GPS).',
      );
    }
    final locationRisk = _assessLocationRisk(
      geoResult,
      capturedOffline: !online,
      bypassedByWfh: false,
      strictLocationOnly: requiresLiveConnection,
    );
    if (locationRisk.blocked) {
      throw Exception(locationRisk.message);
    }

    final securityResult = await _securityService.verifyForAttendance(
      requireBiometric: policyConfig.requiresBiometric,
    );
    final effectiveLocationRisk = locationRisk.withSecurityFallback(
      securityResult.deviceCredentialFallbackUsed,
    );
    await _ensureAttendanceDeviceBinding(
      employee,
      securityResult,
      // The binding method itself only permits this fallback for a transient
      // Firestore outage; permanent permission and device-binding failures
      // continue to block attendance.
      allowOfflineFallback: !requiresLiveConnection,
    );

    if (isCheckIn) {
      // ── CHECK-IN LOGIC ──
      final effectiveStartTime = await _effectiveCheckInStartTime(
        employee: employee,
        dateKey: todayStr,
        policyConfig: policyConfig,
        now: now,
      );
      final deduction = policyConfig.evaluateLateArrival(
        arrivalTime: now,
        employeeStartTime: _formatTime(effectiveStartTime),
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
        biometricVerified: securityResult.biometricVerified,
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
        securityReviewStatus: effectiveLocationRisk.securityReviewStatus,
        locationRiskLevel: effectiveLocationRisk.level,
        locationRiskReasons: effectiveLocationRisk.reasons,
        locationRiskMessage: effectiveLocationRisk.message,
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
        isWithinGeofence: geoResult.isWithinZone || allowsExternalWork,
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
        biometricVerified: securityResult.biometricVerified,
        securityReviewStatus: effectiveLocationRisk.securityReviewStatus,
        locationRiskLevel: effectiveLocationRisk.level,
        locationRiskReasons: effectiveLocationRisk.reasons,
        locationRiskMessage: effectiveLocationRisk.message,
        locationAccuracyMeters: geoResult.accuracyMeters,
        locationDistanceMeters: geoResult.distanceMeters,
        locationAllowedRadiusMeters: geoResult.allowedRadius,
        locationMocked: geoResult.isMocked,
        locationCapturedOffline: !online,
        status: deduction.status,
      );

      var savedOnline = online;
      if (online) {
        try {
          await logRef.set(attendanceLog.toFirestore());
        } catch (error) {
          if (!_isTemporaryFirestoreFailure(error)) rethrow;
          if (requiresLiveConnection) {
            throw Exception(
              'تعذر الاتصال بخدمة الحضور الآن. لم يتم حفظ حضورك بدون إنترنت؛ أعد المحاولة عند عودة الاتصال.',
            );
          }
          savedOnline = false;
          await _offlineQueue.queue(offlineAction);
        }
      } else {
        savedOnline = false;
        await _offlineQueue.queue(offlineAction);
      }
      if (savedOnline && deduction.dayFraction > 0) {
        await _notifyRole(
          role: 'hr_admin',
          type: 'salary_deduction_pending',
          title: 'خصم تأخير بانتظار مراجعة HR',
          body:
              '${employee.displayName}: ${deduction.arabicLabel} (${salaryDeductionAmount.toStringAsFixed(2)} ${employee.salaryCurrency}).',
          data: {'attendanceId': logRef.id},
        );
      }
      if (savedOnline && effectiveLocationRisk.requiresReview) {
        await _notifyLocationSecurityReview(
          employee: employee,
          attendanceId: logRef.id,
          risk: effectiveLocationRisk,
          isCheckOut: false,
        );
      }
    } else {
      // ── CHECK-OUT LOGIC ──
      final checkInDoc = todayLookup.doc;
      final checkInLog = todayLookup.log!;

      if (checkInLog.checkInTime == null) {
        throw Exception(
          'لا يوجد تسجيل حضور صالح لهذا اليوم. اضغط تسجيل حضور أولاً.',
        );
      }

      if (checkInLog.checkOutTime != null) {
        throw Exception('لقد قمت بتسجيل الانصراف بالفعل لهذا اليوم.');
      }

      final checkInTime = checkInLog.checkInTime ?? now;
      final totalWorkHours = now.difference(checkInTime).inMinutes / 60.0;
      final allowedCheckoutFrom = await _effectiveCheckoutAllowedFrom(
        employee: employee,
        dateKey: todayStr,
        policyConfig: policyConfig,
        now: now,
      );
      final latestCheckoutWithoutDeduction = AttendancePolicy.parseTimeOnDate(
        now,
        policyConfig.latestCheckoutTime,
      );
      final needsCheckoutDeduction =
          now.isBefore(allowedCheckoutFrom) ||
          now.isAfter(latestCheckoutWithoutDeduction);
      final checkoutDeductionLabel = now.isAfter(latestCheckoutWithoutDeduction)
          ? 'خصم ربع يوم - تسجيل انصراف بعد 11 مساءً'
          : 'خصم ربع يوم - انصراف مبكر';
      final checkoutDeductionCode = now.isAfter(latestCheckoutWithoutDeduction)
          ? 'late_checkout_after_11_quarter_day'
          : 'early_checkout_quarter_day';

      final earlyCheckoutDeduction = _buildCheckoutDeductionPatch(
        employee: employee,
        currentLog: checkInLog,
        reasonCode: checkoutDeductionCode,
        reasonLabel: checkoutDeductionLabel,
        now: now,
        applies: needsCheckoutDeduction,
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
        biometricVerified: securityResult.biometricVerified,
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
            : checkoutDeductionCode,
        salaryDeductionLabel: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionLabel
            : earlyCheckoutDeduction.label,
        salaryDeductionApprovalStatus: earlyCheckoutDeduction.patch.isEmpty
            ? checkInLog.salaryDeductionApprovalStatus
            : 'pending_hr',
        securityReviewStatus: effectiveLocationRisk.securityReviewStatus,
        locationRiskLevel: effectiveLocationRisk.level,
        locationRiskReasons: effectiveLocationRisk.reasons,
        locationRiskMessage: effectiveLocationRisk.message,
        status: checkInLog.status,
      );

      var savedOnline = online && checkInDoc != null;
      if (savedOnline) {
        try {
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
            'checkOutBiometricVerified': securityResult.biometricVerified,
            ...effectiveLocationRisk.toCheckoutFirestorePatch(geoResult),
            ...earlyCheckoutDeduction.patch,
          });
        } catch (error) {
          if (!_isTemporaryFirestoreFailure(error)) rethrow;
          if (requiresLiveConnection) {
            throw Exception(
              'تعذر الاتصال بخدمة الحضور الآن. لم يتم حفظ انصرافك بدون إنترنت؛ أعد المحاولة عند عودة الاتصال.',
            );
          }
          savedOnline = false;
          await _offlineQueue.queue(offlineAction);
        }
      } else {
        await _offlineQueue.queue(offlineAction);
      }

      if (savedOnline && earlyCheckoutDeduction.shouldNotify) {
        await _notifyRole(
          role: 'hr_admin',
          type: 'salary_deduction_pending',
          title: '${earlyCheckoutDeduction.label} بانتظار مراجعة HR',
          body:
              '${employee.displayName}: ${earlyCheckoutDeduction.label} (${earlyCheckoutDeduction.amount.toStringAsFixed(2)} ${employee.salaryCurrency}).',
          data: {'attendanceId': checkInDoc?.id ?? checkInLog.attendanceId},
        );
      }
      if (savedOnline && effectiveLocationRisk.requiresReview) {
        await _notifyLocationSecurityReview(
          employee: employee,
          attendanceId: checkInDoc?.id ?? checkInLog.attendanceId,
          risk: effectiveLocationRisk,
          isCheckOut: true,
        );
      }
    }
  }

  Future<void> syncPendingOfflineAttendance() {
    return _offlineQueue.syncPendingActions();
  }

  /// Binds the current trusted device before automatic attendance is enabled.
  /// This deliberately uses the same one-device-per-account transaction as
  /// manual attendance, without prompting for biometrics.
  Future<AttendanceSecurityResult> prepareAutomaticAttendance(
    UserModel employee,
  ) async {
    final security = await _securityService.verifyForAttendance(
      requireBiometric: false,
    );
    await _ensureAttendanceDeviceBinding(
      employee,
      security,
      allowOfflineFallback: false,
    );
    return security;
  }

  bool _isTemporaryFirestoreFailure(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return const {
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'resource-exhausted',
        'internal',
      }.contains(error.code);
    }
    final message = error.toString().toLowerCase();
    return message.contains('cloud_firestore/unavailable') ||
        message.contains('service is currently unavailable') ||
        message.contains('deadline-exceeded');
  }

  Future<AttendancePolicyConfig> policyConfigForDisplay() {
    return _policyService.getPolicyConfig();
  }

  Future<DateTime> checkoutAllowedFromForDisplay(
    UserModel employee, {
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final policyConfig = await _policyService.getPolicyConfig();
    final dateKey = DateFormat('yyyy-MM-dd').format(currentTime);
    return _effectiveCheckoutAllowedFrom(
      employee: employee,
      dateKey: dateKey,
      policyConfig: policyConfig,
      now: currentTime,
    );
  }

  _LocationRiskAssessment _assessLocationRisk(
    GeofenceResult geoResult, {
    required bool capturedOffline,
    required bool bypassedByWfh,
    required bool strictLocationOnly,
  }) {
    if (bypassedByWfh) {
      return const _LocationRiskAssessment.clean();
    }

    final reasons = <String>[];
    final messages = <String>[];

    if (geoResult.isMocked) {
      return const _LocationRiskAssessment.blocked(
        message: 'تم رفض العملية بسبب اكتشاف موقع وهمي أو Mock GPS.',
        reasons: ['mock_location'],
      );
    }

    if (strictLocationOnly && geoResult.accuracyMeters > 50) {
      return _LocationRiskAssessment.blocked(
        message:
            'دقة الموقع يجب أن تكون 50 متراً أو أفضل لتسجيل الحضور بالموقع فقط. انتقل لمكان مفتوح وفعّل الموقع الدقيق ثم أعد المحاولة.',
        reasons: const ['location_only_accuracy_too_low'],
      );
    }

    if (strictLocationOnly && geoResult.accuracyMeters > 25) {
      reasons.add('location_only_accuracy_review');
      messages.add(
        'دقة الموقع متوسطة: ${geoResult.accuracyMeters.toStringAsFixed(0)} متر',
      );
    }

    if (geoResult.accuracyMeters > 80) {
      return _LocationRiskAssessment.blocked(
        message:
            'دقة الموقع ضعيفة جداً (${geoResult.accuracyMeters.toStringAsFixed(0)} متر). انتقل لمكان مفتوح وفعّل GPS ثم أعد المحاولة.',
        reasons: const ['very_poor_accuracy'],
      );
    }

    if (geoResult.accuracyMeters > 35) {
      reasons.add('weak_accuracy');
      messages.add(
        'دقة الموقع ضعيفة: ${geoResult.accuracyMeters.toStringAsFixed(0)} متر',
      );
    }

    final distanceToEdge = geoResult.allowedRadius - geoResult.distanceMeters;
    final edgeTolerance = geoResult.accuracyMeters.clamp(15, 50).toDouble();
    if (geoResult.isWithinZone &&
        distanceToEdge >= 0 &&
        distanceToEdge < edgeTolerance) {
      reasons.add('near_geofence_edge');
      messages.add(
        'الموقع قريب من حدود الفرع: ${distanceToEdge.toStringAsFixed(0)} متر من الحد',
      );
    }

    if (capturedOffline) {
      reasons.add('offline_capture');
      messages.add('تم تسجيل الحركة بدون اتصال وسيتم مراجعتها بعد المزامنة');
    }

    if (reasons.isEmpty) {
      return const _LocationRiskAssessment.clean();
    }

    final highRisk =
        reasons.contains('weak_accuracy') ||
        reasons.contains('location_only_accuracy_review') ||
        reasons.contains('offline_capture');
    return _LocationRiskAssessment.review(
      level: highRisk ? 'high' : 'medium',
      reasons: reasons,
      message: messages.join('، '),
    );
  }

  Future<void> _notifyLocationSecurityReview({
    required UserModel employee,
    required String attendanceId,
    required _LocationRiskAssessment risk,
    required bool isCheckOut,
  }) {
    return _notifyRole(
      role: 'hr_admin',
      type: 'attendance_security_review',
      title: isCheckOut
          ? 'انصراف يحتاج مراجعة أمنية'
          : 'حضور يحتاج مراجعة أمنية',
      body: '${employee.displayName}: ${risk.message}',
      data: {'attendanceId': attendanceId},
    );
  }

  Future<AttendanceModel?> loadTodayAttendanceForDisplay(String userId) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return (await _loadTodayAttendance(userId, todayStr)).log;
  }

  Future<_TodayAttendanceLookup> _loadTodayAttendance(
    String userId,
    String todayStr,
  ) async {
    final attendanceId = '${userId}_$todayStr';
    try {
      final doc = await _db.collection('attendance').doc(attendanceId).get();
      if (doc.exists) {
        return _TodayAttendanceLookup(
          doc: doc,
          log: AttendanceModel.fromFirestore(doc),
        );
      }
    } catch (_) {
      try {
        final doc = await _db
            .collection('attendance')
            .doc(attendanceId)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists) {
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
    final legacyDeviceId = securityResult.legacyDeviceId?.trim() ?? '';
    if (deviceId.isEmpty) {
      throw Exception('تعذر قراءة رقم الجهاز. أعد المحاولة أو تواصل مع HR.');
    }

    final localOwner = await _offlineQueue.localDeviceOwner(deviceId);
    final isOnline = await _offlineQueue.isOnline();
    final locallyRegisteredDevice =
        employee.registeredAttendanceDeviceId?.trim() ?? '';

    if (allowOfflineFallback && !isOnline) {
      if (localOwner != null && localOwner != employee.uid) {
        throw Exception(
          'هذا الجهاز مربوط محلياً بحساب موظف آخر. اتصل بالإنترنت للتحقق أو اطلب من HR إعادة الضبط.',
        );
      }
      if (locallyRegisteredDevice.isEmpty && localOwner == null) {
        throw Exception(
          'لأمان تسجيل الحضور، يجب تسجيل أول حضور مرة واحدة وأنت متصل بالإنترنت لربط الحساب بهذا الجهاز.',
        );
      }
      if (locallyRegisteredDevice.isNotEmpty &&
          locallyRegisteredDevice != deviceId) {
        throw Exception(
          'هذا الحساب مربوط بجهاز حضور آخر. اتصل بالإنترنت أو اطلب من HR إعادة ضبط جهاز الحضور.',
        );
      }
      await _offlineQueue.rememberLocalDeviceOwner(
        deviceId: deviceId,
        userId: employee.uid,
      );
      return;
    }

    final canMigrateLegacyDevice =
        legacyDeviceId.isNotEmpty && locallyRegisteredDevice == legacyDeviceId;

    if (locallyRegisteredDevice.isNotEmpty && !canMigrateLegacyDevice) {
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
        final shouldMigrateLegacyDevice =
            legacyDeviceId.isNotEmpty &&
            registeredDeviceId == legacyDeviceId &&
            registeredDeviceId != deviceId;

        if (registeredDeviceId.isNotEmpty) {
          if (registeredDeviceId == deviceId) {
            return;
          }
          if (!shouldMigrateLegacyDevice) {
            throw Exception(
              'هذا الحساب مربوط بجهاز حضور آخر. اطلب من HR إعادة ضبط جهاز الحضور قبل استخدام هذا الجهاز.',
            );
          }
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
      if (e is Exception && e.toString().contains('مربوط')) {
        rethrow;
      }
      if (!allowOfflineFallback || !_isTemporaryFirestoreFailure(e)) rethrow;

      if (localOwner != null && localOwner != employee.uid) {
        throw Exception(
          'هذا الجهاز مربوط محلياً بحساب موظف آخر. اتصل بالإنترنت للتحقق أو اطلب من HR إعادة الضبط.',
        );
      }

      if (locallyRegisteredDevice.isEmpty && localOwner == null) {
        throw Exception(
          'لأمان تسجيل الحضور، يجب تسجيل أول حضور مرة واحدة وأنت متصل بالإنترنت لربط الحساب بهذا الجهاز.',
        );
      }
      if (locallyRegisteredDevice.isNotEmpty &&
          locallyRegisteredDevice != deviceId &&
          !canMigrateLegacyDevice) {
        throw Exception(
          'هذا الحساب مربوط بجهاز حضور آخر. اتصل بالإنترنت للتحقق أو اطلب من HR إعادة الضبط.',
        );
      }

      await _offlineQueue.rememberLocalDeviceOwner(
        deviceId: deviceId,
        userId: employee.uid,
      );
    }
  }

  Future<DateTime> _effectiveCheckInStartTime({
    required UserModel employee,
    required String dateKey,
    required AttendancePolicyConfig policyConfig,
    required DateTime now,
  }) async {
    final baseStart = AttendancePolicy.parseTimeOnDate(
      now,
      employee.workSchedule.startTime ?? policyConfig.defaultStartTime,
    );
    final permission = await _approvedPermissionForDate(
      userId: employee.uid,
      dateKey: dateKey,
      type: 'late_arrival',
    );
    if (permission == null) return baseStart;
    final minutes = permission['durationMinutes'] as int? ?? 0;
    if (minutes <= 0) return baseStart;
    return baseStart.add(Duration(minutes: minutes));
  }

  Future<DateTime> _effectiveCheckoutAllowedFrom({
    required UserModel employee,
    required String dateKey,
    required AttendancePolicyConfig policyConfig,
    required DateTime now,
  }) async {
    final baseEnd = AttendancePolicy.parseTimeOnDate(
      now,
      employee.workSchedule.endTime ?? policyConfig.defaultEndTime,
    );
    final permission = await _approvedPermissionForDate(
      userId: employee.uid,
      dateKey: dateKey,
      type: 'early_leave',
    );
    if (permission == null) return baseEnd;
    final minutes = permission['durationMinutes'] as int? ?? 0;
    if (minutes <= 0) return baseEnd;
    return baseEnd.subtract(Duration(minutes: minutes));
  }

  Future<Map<String, dynamic>?> _approvedPermissionForDate({
    required String userId,
    required String dateKey,
    required String type,
  }) async {
    try {
      final snap = await _db
          .collection('permissions')
          .where('userId', isEqualTo: userId)
          .where('requestDate', isEqualTo: dateKey)
          .where('permissionType', isEqualTo: type)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatArabicTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
      if (await _fieldAssignmentService.skipsCheckoutForDate(
        userId: employee.uid,
        dateKey: log.date,
      )) {
        continue;
      }

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

      final remoteSub = remoteStream.listen(
        (snapshot) {
          remoteLogs = snapshot.docs
              .map((doc) => AttendanceModel.fromFirestore(doc))
              .toList();
          emitMerged();
        },
        onError: (_) {
          remoteLogs = <AttendanceModel>[];
          emitMerged();
        },
      );
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

  Future<void> approveSecurityReview(
    String attendanceId,
    String reviewerId, {
    required bool checkout,
  }) async {
    await _reviewAttendanceSecurity(
      attendanceId,
      reviewerId,
      'approved',
      checkout: checkout,
    );
  }

  Future<void> rejectSecurityReview(
    String attendanceId,
    String reviewerId, {
    required bool checkout,
  }) async {
    await _reviewAttendanceSecurity(
      attendanceId,
      reviewerId,
      'rejected',
      checkout: checkout,
    );
  }

  Future<void> _reviewAttendanceSecurity(
    String attendanceId,
    String reviewerId,
    String status, {
    required bool checkout,
  }) async {
    final update = checkout
        ? {
            'checkoutSecurityReviewStatus': status,
            'checkoutSecurityReviewedBy': reviewerId,
            'checkoutSecurityReviewedAt': FieldValue.serverTimestamp(),
          }
        : {
            'securityReviewStatus': status,
            'securityReviewedBy': reviewerId,
            'securityReviewedAt': FieldValue.serverTimestamp(),
          };

    await _db.collection('attendance').doc(attendanceId).update(update);

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: checkout
          ? 'checkout_security_review_$status'
          : 'attendance_security_review_$status',
      targetCollection: 'attendance',
      targetId: attendanceId,
    );

    final doc = await _db.collection('attendance').doc(attendanceId).get();
    if (!doc.exists) return;
    final data = doc.data() ?? <String, dynamic>{};
    final userId = data['userId'] as String?;
    if (userId == null || userId.isEmpty) return;

    final notifRef = _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .doc();
    await notifRef.set({
      'notificationId': notifRef.id,
      'type': 'attendance_security_reviewed',
      'title': status == 'approved'
          ? 'تم قبول مراجعة الحضور الأمنية'
          : 'تم رفض مراجعة الحضور الأمنية',
      'body': status == 'approved'
          ? 'تم اعتماد حركة الحضور بعد مراجعة مؤشرات الموقع.'
          : 'تم رفض حركة الحضور بعد مراجعة مؤشرات الموقع. تواصل مع HR إذا احتجت توضيحاً.',
      'data': {'attendanceId': attendanceId},
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
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

    try {
      await AuditLogService.instance.record(
        actorId: reviewerId,
        action: 'salary_deduction_$status',
        targetCollection: 'attendance',
        targetId: attendanceId,
      );
    } catch (_) {}

    // Get attendance doc to find employee ID
    try {
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
            'pushSent': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          await _db.collection('users').doc(userId).update({
            'unreadNotifications': FieldValue.increment(1),
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _notifyRole({
    required String role,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await RoleNotificationService.instance.notifyRole(
      role: role,
      type: type,
      title: title,
      body: body,
      data: data,
    );
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

class _LocationRiskAssessment {
  final bool blocked;
  final String level;
  final List<String> reasons;
  final String message;
  final String securityReviewStatus;

  bool get requiresReview => securityReviewStatus == 'pending_hr';

  const _LocationRiskAssessment._({
    required this.blocked,
    required this.level,
    required this.reasons,
    required this.message,
    required this.securityReviewStatus,
  });

  const _LocationRiskAssessment.clean()
    : this._(
        blocked: false,
        level: 'low',
        reasons: const [],
        message: '',
        securityReviewStatus: 'none',
      );

  const _LocationRiskAssessment.blocked({
    required String message,
    required List<String> reasons,
  }) : this._(
         blocked: true,
         level: 'blocked',
         reasons: reasons,
         message: message,
         securityReviewStatus: 'blocked',
       );

  const _LocationRiskAssessment.review({
    required String level,
    required List<String> reasons,
    required String message,
  }) : this._(
         blocked: false,
         level: level,
         reasons: reasons,
         message: message,
         securityReviewStatus: 'pending_hr',
       );

  Map<String, dynamic> toCheckoutFirestorePatch(GeofenceResult geoResult) {
    return {
      'checkoutSecurityReviewStatus': securityReviewStatus,
      'checkoutLocationRiskLevel': level,
      'checkoutLocationRiskReasons': reasons,
      if (message.isNotEmpty) 'checkoutLocationRiskMessage': message,
      'checkoutLocationAccuracyMeters': geoResult.accuracyMeters,
      'checkoutLocationDistanceMeters': geoResult.distanceMeters,
      'checkoutLocationAllowedRadiusMeters': geoResult.allowedRadius,
      'checkoutLocationMocked': geoResult.isMocked,
      'checkoutLocationCapturedOffline': false,
    };
  }

  _LocationRiskAssessment withSecurityFallback(bool fallbackUsed) {
    if (!fallbackUsed || blocked) return this;
    final nextReasons = [...reasons, 'device_credential_fallback'];
    final fallbackMessage =
        'تم استخدام قفل الجهاز بدلاً من البصمة لأن الجهاز لا يدعم بصمة/وجه';
    final nextMessage = message.isEmpty
        ? fallbackMessage
        : '$message، $fallbackMessage';
    return _LocationRiskAssessment.review(
      level: 'high',
      reasons: nextReasons,
      message: nextMessage,
    );
  }
}

class _TodayAttendanceLookup {
  final DocumentSnapshot<Map<String, dynamic>>? doc;
  final AttendanceModel? log;

  const _TodayAttendanceLookup({this.doc, this.log});
}
