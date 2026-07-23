import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/complaint_model.dart';
import '../models/user_model.dart';
import '../models/notification_route_policy.dart';
import 'role_notification_service.dart';

class ComplaintService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> submitComplaint({
    required UserModel employee,
    required String title,
    required String body,
    String? attachmentUrl,
  }) async {
    final ref = _db.collection('complaints').doc();
    final complaint = ComplaintModel(
      complaintId: ref.id,
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      title: title.trim(),
      body: body.trim(),
      attachmentUrl: attachmentUrl?.trim(),
      status: 'new',
      submittedAt: DateTime.now(),
    );

    await ref.set(complaint.toFirestore());
    await _notifyRole(
      role: 'hr_admin',
      type: 'complaint_new',
      title: 'شكوى جديدة',
      body: '${employee.displayName}: ${title.trim()}',
      data: {'complaintId': ref.id},
    );
  }

  Future<void> markReviewed(String complaintId, String reviewerId) async {
    final ref = _db.collection('complaints').doc(complaintId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw Exception('الشكوى غير موجودة');
    final complaint = ComplaintModel.fromFirestore(snapshot);

    await ref.update({
      'status': 'reviewed',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    final notificationRef = _db
        .collection('notifications')
        .doc(complaint.userId)
        .collection('items')
        .doc();
    await notificationRef.set({
      'notificationId': notificationRef.id,
      'type': 'complaint_reviewed',
      'title': 'تمت مراجعة الشكوى',
      'body': 'تمت مراجعة شكواك: ${complaint.title}',
      'data': NotificationRoutePolicy.dataWithRoute('complaint_reviewed', {
        'complaintId': complaintId,
      }),
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(complaint.userId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
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
