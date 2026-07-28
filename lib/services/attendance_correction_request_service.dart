import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../models/employee_role.dart';
import '../models/user_model.dart';
import 'attendance_service.dart';
import 'role_notification_service.dart';

class AttendanceCorrectionRequestService {
  AttendanceCorrectionRequestService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final AttendanceService _attendanceService = AttendanceService();

  Stream<List<AttendanceModel>> correctionEligibleAttendance(String userId) {
    return _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .limit(120)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(AttendanceModel.fromFirestore)
              .where(
                (item) =>
                    item.checkInTime != null &&
                    (item.isLate || item.lateMinutes > 0) &&
                    item.salaryDeductionFraction > 0,
              )
              .toList();
          items.sort((a, b) => b.date.compareTo(a.date));
          return items.take(60).toList();
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> requestsForEmployee(
    String userId,
  ) {
    return _db
        .collection('attendanceCorrectionRequests')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingForHr() {
    return _db
        .collection('attendanceCorrectionRequests')
        .where('status', isEqualTo: 'pending_hr')
        .limit(50)
        .snapshots();
  }

  Future<void> cancelRequest(String requestId, String userId) async {
    await _db.collection('attendanceCorrectionRequests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': userId,
    });
  }

  Future<void> submit({
    required UserModel employee,
    required AttendanceModel attendance,
    required DateTime requestedCheckInTime,
    required String reason,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.length < 5) {
      throw Exception('اكتب سبب التصحيح بوضوح.');
    }
    if (attendance.userId != employee.uid || attendance.checkInTime == null) {
      throw Exception('سجل الحضور المحدد غير صالح للتصحيح.');
    }

    final original = attendance.checkInTime!;
    if (requestedCheckInTime.year != original.year ||
        requestedCheckInTime.month != original.month ||
        requestedCheckInTime.day != original.day) {
      throw Exception('وقت التصحيح يجب أن يكون في يوم الحضور نفسه.');
    }
    if (requestedCheckInTime.isAfter(original)) {
      throw Exception('وقت الوصول المقترح يجب ألا يكون بعد الوقت المسجل.');
    }

    final duplicate = await _db
        .collection('attendanceCorrectionRequests')
        .where('attendanceId', isEqualTo: attendance.attendanceId)
        .get();
    if (duplicate.docs.any((doc) => doc.data()['status'] == 'pending_hr')) {
      throw Exception('يوجد طلب تصحيح معلق لهذا اليوم بالفعل.');
    }

    final ref = _db.collection('attendanceCorrectionRequests').doc();
    await ref.set({
      'requestId': ref.id,
      'userId': employee.uid,
      'employeeId': employee.employeeId,
      'employeeName': employee.displayName,
      'department': employee.department,
      'attendanceId': attendance.attendanceId,
      'attendanceDate': attendance.date,
      'originalCheckInTime': Timestamp.fromDate(original),
      'requestedCheckInTime': Timestamp.fromDate(requestedCheckInTime),
      'reason': cleanReason,
      'status': 'pending_hr',
      'submittedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await RoleNotificationService.instance.notifyRole(
      role: EmployeeRole.hrAdmin,
      type: 'attendance_correction_pending_hr',
      title: 'طلب تصحيح وقت حضور',
      body: '${employee.displayName} أرسل طلب تصحيح وقت حضور لمراجعة HR.',
      data: {
        'route': '/manager/requests',
        'requestId': ref.id,
        'attendanceId': attendance.attendanceId,
      },
      includeSuperAdmins: false,
    );
  }

  Future<void> review({
    required String requestId,
    required UserModel reviewer,
    required bool approve,
    required String comment,
  }) async {
    if (!EmployeeRole.isHrStaff(reviewer.role)) {
      throw Exception('طلبات تصحيح الوقت يراجعها HR فقط.');
    }

    final ref = _db.collection('attendanceCorrectionRequests').doc(requestId);
    final request = await ref.get();
    if (!request.exists || request.data()?['status'] != 'pending_hr') {
      throw Exception('الطلب غير موجود أو تمت مراجعته بالفعل.');
    }
    final data = request.data()!;
    final employeeId = data['userId'] as String? ?? '';
    if (employeeId == reviewer.uid) {
      throw Exception('لا يمكنك مراجعة طلب التصحيح الخاص بك.');
    }

    if (approve) {
      final corrected = data['requestedCheckInTime'];
      if (corrected is! Timestamp) {
        throw Exception('وقت التصحيح غير صالح.');
      }
      await _attendanceService.correctCheckInTime(
        attendanceId: data['attendanceId'] as String? ?? '',
        reviewerId: reviewer.uid,
        correctedTime: corrected.toDate(),
        reason: data['reason'] as String? ?? '',
      );
    }

    await ref.update({
      'status': approve ? 'approved' : 'rejected',
      'reviewedBy': reviewer.uid,
      'reviewerName': reviewer.displayName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerComment': comment.trim(),
    });

    if (employeeId.isNotEmpty) {
      final notification = _db
          .collection('notifications')
          .doc(employeeId)
          .collection('items')
          .doc();
      await notification.set({
        'notificationId': notification.id,
        'type': approve
            ? 'attendance_correction_approved'
            : 'attendance_correction_rejected',
        'title': approve
            ? 'تم قبول تصحيح وقت الحضور'
            : 'تم رفض تصحيح وقت الحضور',
        'body': comment.trim().isEmpty
            ? (approve
                  ? 'تم تعديل وقت الحضور وإعادة حساب الخصم.'
                  : 'راجع سجل طلباتك لمعرفة حالة الطلب.')
            : comment.trim(),
        'data': {'route': '/employee/requests', 'requestId': requestId},
        'isRead': false,
        'pushSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('users').doc(employeeId).update({
        'unreadNotifications': FieldValue.increment(1),
      });
    }
  }
}
