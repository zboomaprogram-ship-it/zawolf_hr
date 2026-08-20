import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/notification_route_policy.dart';

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
    String? eventId,
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
          eventId: eventId,
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
    if (role == EmployeeRole.hrAdmin) {
      await _addDirectoryRecipients(targets, EmployeeRole.legacyHrManager);
    }
    if (includeSuperAdmins && role != EmployeeRole.superAdmin) {
      await _addDirectoryRecipients(targets, EmployeeRole.superAdmin);
    }

    if (targets.isNotEmpty) return targets;

    // Fallback for admin-owned flows before the public recipient directory is
    // seeded. Employee-owned flows cannot rely on this because user docs stay
    // protected by Firestore rules.
    await _addUserQueryRecipients(targets, role);
    if (role == EmployeeRole.hrAdmin) {
      await _addUserQueryRecipients(targets, EmployeeRole.legacyHrManager);
    }
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
    String? eventId,
  }) async {
    final resolvedEventId = eventId ?? _eventIdFromData(type, data);
    final items = _db
        .collection('notifications')
        .doc(recipientId)
        .collection('items');
    final notifRef = resolvedEventId == null
        ? items.doc()
        : items.doc(_stableId('$recipientId:$resolvedEventId'));

    try {
      await notifRef.set({
        'notificationId': notifRef.id,
        'type': type,
        'title': title,
        'body': body,
        'data': NotificationRoutePolicy.dataWithRoute(type, data),
        'isRead': false,
        'pushSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      // Notification senders can create recipient items but cannot read or
      // update them. A repeated stable event therefore reaches the update
      // rule and is denied, which safely means it was already queued.
      if (resolvedEventId != null && error.code == 'permission-denied') return;
      rethrow;
    }

    try {
      await _db.collection('users').doc(recipientId).update({
        'unreadNotifications': FieldValue.increment(1),
      });
    } catch (_) {
      // The notification document is the source of truth. A stale unread
      // counter must never make the primary request appear to have failed.
    }
  }

  String? _eventIdFromData(String type, Map<String, dynamic>? data) {
    if (data == null) return null;
    const keys = <String>[
      'permissionId',
      'leaveId',
      'fieldMissionId',
      'administrativeRequestId',
      'attendanceId',
      'advanceId',
      'resignationId',
      'requestId',
      'taskId',
      'deductionId',
    ];
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return '$type:$key:$value';
    }
    return null;
  }

  String _stableId(String value) {
    // FNV-1a is stable across processes, unlike String.hashCode on web.
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'event_${hash.toRadixString(16).padLeft(8, '0')}';
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
