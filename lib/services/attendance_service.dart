import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_policy.dart';
import 'attendance_security_service.dart';
import 'audit_log_service.dart';
import 'company_day_off_service.dart';
import 'geofence_service.dart';
import 'onesignal_service.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GeofenceService _geofenceService = GeofenceService();
  final AttendanceSecurityService _securityService =
      AttendanceSecurityService();
  final CompanyDayOffService _dayOffService = CompanyDayOffService();

  // Handle employee Check-In or Check-Out
  Future<void> handleCheckInOrCheckOut(UserModel employee) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    await _flagMissedCheckouts(employee, todayStr);

    // Query today only, so an unclosed previous day never blocks a new day.
    final existingLogs = await _db
        .collection('attendance')
        .where('userId', isEqualTo: employee.uid)
        .where('date', isEqualTo: todayStr)
        .limit(1)
        .get();

    final isCheckIn = existingLogs.docs.isEmpty;
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

    if (existingLogs.docs.isEmpty) {
      // ── CHECK-IN LOGIC ──
      final companyStartTimeStr = employee.workSchedule.startTime ?? '09:00';
      final deduction = AttendancePolicy.evaluateLateArrival(
        arrivalTime: now,
        startTime: companyStartTimeStr,
      );
      final salaryDeductionAmount =
          AttendancePolicy.calculateSalaryDeductionAmount(
            monthlySalary: employee.baseMonthlySalary,
            dayFraction: deduction.dayFraction,
          );

      final logRef = _db
          .collection('attendance')
          .doc('${employee.uid}_$todayStr');
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

      await logRef.set(attendanceLog.toFirestore());
      if (deduction.dayFraction > 0) {
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
      final checkInDoc = existingLogs.docs.first;
      final checkInLog = AttendanceModel.fromFirestore(checkInDoc);

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
        applies: _isEarlyCheckout(now, employee.workSchedule.endTime),
      );

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

      if (earlyCheckoutDeduction.shouldNotify) {
        await _notifyRole(
          role: 'hr_admin',
          type: 'salary_deduction_pending',
          title: 'خصم انصراف مبكر بانتظار مراجعة HR',
          body:
              '${employee.displayName}: ${earlyCheckoutDeduction.label} (${earlyCheckoutDeduction.amount.toStringAsFixed(2)} ${employee.salaryCurrency}).',
          data: {'attendanceId': checkInDoc.id},
        );
      }
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
  }) {
    if (!applies || currentLog.salaryDeductionFraction >= 0.25) {
      return const _DeductionPatch.empty();
    }

    final amount = AttendancePolicy.calculateSalaryDeductionAmount(
      monthlySalary: employee.baseMonthlySalary,
      dayFraction: 0.25,
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

    return _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: '$monthKey-01')
        .where('date', isLessThan: nextMonthStr)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AttendanceModel.fromFirestore(doc))
              .toList();
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

        await OneSignalService.sendPushToUsers(
          targetUids: [userId],
          title: title,
          body: body,
          additionalData: {'attendanceId': attendanceId},
        );
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

    await OneSignalService.sendPushToUsers(
      targetUids: targets.toList(),
      title: title,
      body: body,
      additionalData: data,
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
