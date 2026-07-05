import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/leave_model.dart';
import 'audit_log_service.dart';

class LeaveService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
      SettableMetadata(
        contentType: 'application/pdf',
      ), // typical document format
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
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // Submit leave request
  Future<void> submitLeaveRequest(LeaveModel req, UserModel employee) async {
    if (!['annual', 'sick', 'casual', 'day_off'].contains(req.leaveType)) {
      throw Exception('نوع الإجازة غير صحيح');
    }

    // 1. Validate overlaps (basic check against other active leaves)
    final overlaps = await _db
        .collection('leaves')
        .where('userId', isEqualTo: req.userId)
        .where('status', whereIn: ['approved', 'pending'])
        .get();

    for (final doc in overlaps.docs) {
      final existing = LeaveModel.fromFirestore(doc);
      if (req.startDate.isBefore(
            existing.endDate.add(const Duration(days: 1)),
          ) &&
          req.endDate.isAfter(
            existing.startDate.subtract(const Duration(days: 1)),
          )) {
        throw Exception('يوجد طلب إجازة متداخل آخر بالفعل في هذه التواريخ.');
      }
    }

    final reqRef = _db.collection('leaves').doc();
    final finalModel = LeaveModel(
      leaveId: reqRef.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      leaveType: req.leaveType,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      reason: req.reason,
      attachmentUrl: req.attachmentUrl,
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    await reqRef.set(finalModel.toFirestore());

    // 3. Notify manager
    if (req.managerId.isNotEmpty) {
      try {
        await _createNotification(
          recipientId: req.managerId,
          type: 'leave_request_submitted',
          title: 'طلب إجازة جديد 📝',
          body:
              'يطلب ${req.employeeName} إجازة (${req.leaveType}) لمدّة ${req.numberOfDays} يوم.',
          data: {'leaveId': reqRef.id},
        );
      } catch (_) {}
    }
  }

  // Approve Leave
  Future<void> approveLeave(String leaveId, String reviewerId) async {
    final docRef = _db.collection('leaves').doc(leaveId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('طلب الإجازة غير موجود');
    final leave = LeaveModel.fromFirestore(doc);

    await docRef.update({
      'status': 'approved',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

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

    // 3. Notify employee
    await _createNotification(
      recipientId: leave.userId,
      type: 'leave_approved',
      title: 'تم قبول طلب الإجازة ✅',
      body: 'تمت الموافقة على طلب إجازتك لمدّة ${leave.numberOfDays} يوم.',
    );
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

    await docRef.update({
      'status': 'rejected',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerComment': comment,
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'leave_rejected',
      targetCollection: 'leaves',
      targetId: leaveId,
      metadata: {'userId': leave.userId, 'leaveType': leave.leaveType},
    );

    // Notify employee
    await _createNotification(
      recipientId: leave.userId,
      type: 'leave_rejected',
      title: 'تم رفض طلب الإجازة ❌',
      body: 'تم رفض طلب إجازتك. السبب: $comment',
    );
  }

  // Private Helper to create notification records
  Future<void> _createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final notifRef = _db
        .collection('notifications')
        .doc(recipientId)
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

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
