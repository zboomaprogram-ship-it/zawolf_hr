import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogService {
  AuditLogService._();

  static final AuditLogService instance = AuditLogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> record({
    required String actorId,
    required String action,
    required String targetCollection,
    required String targetId,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (actorId.isEmpty) return;

    await _db.collection('auditLogs').add({
      'actorId': actorId,
      'action': action,
      'targetCollection': targetCollection,
      'targetId': targetId,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
