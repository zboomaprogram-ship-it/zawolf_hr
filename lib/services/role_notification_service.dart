import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';

class RoleNotificationService {
  RoleNotificationService._internal();
  static final RoleNotificationService instance =
      RoleNotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> notifyRole({
    required String role,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool includeSuperAdmins = true,
  }) async {
    try {
      final targets = await recipientIdsForRole(
        role,
        includeSuperAdmins: includeSuperAdmins,
      );

      for (final userId in targets) {
        await createNotification(
          recipientId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (_) {
      // Notification delivery must not block the primary workflow.
    }
  }

  Future<Set<String>> recipientIdsForRole(
    String role, {
    bool includeSuperAdmins = true,
  }) async {
    final targets = <String>{};
    await _addDirectoryRecipients(targets, role);
    if (includeSuperAdmins && role != EmployeeRole.superAdmin) {
      await _addDirectoryRecipients(targets, EmployeeRole.superAdmin);
    }

    if (targets.isNotEmpty) return targets;

    // Fallback for admin-owned flows before the public recipient directory is
    // seeded. Employee-owned flows cannot rely on this because user docs stay
    // protected by Firestore rules.
    await _addUserQueryRecipients(targets, role);
    if (includeSuperAdmins && role != EmployeeRole.superAdmin) {
      await _addUserQueryRecipients(targets, EmployeeRole.superAdmin);
    }
    return targets;
  }

  Future<void> createNotification({
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

  Future<void> _addDirectoryRecipients(Set<String> targets, String role) async {
    try {
      final doc = await _db
          .collection('notificationRecipients')
          .doc(role)
          .get();
      final ids = doc.data()?['userIds'] as List<dynamic>? ?? <dynamic>[];
      targets.addAll(
        ids.whereType<String>().where((id) => id.trim().isNotEmpty),
      );
    } catch (_) {}
  }

  Future<void> _addUserQueryRecipients(Set<String> targets, String role) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      targets.addAll(snap.docs.map((doc) => doc.id));
    } catch (_) {}
  }
}
