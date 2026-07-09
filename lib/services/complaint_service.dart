import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/complaint_model.dart';
import '../models/user_model.dart';

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
    await _db.collection('complaints').doc(complaintId).update({
      'status': 'reviewed',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
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
      // Notification delivery must not block the complaint itself.
    }
  }
}
