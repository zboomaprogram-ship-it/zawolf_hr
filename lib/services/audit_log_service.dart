import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final effectiveActorId =
          (currentUid != null && currentUid.isNotEmpty) ? currentUid : actorId;

      if (effectiveActorId.isEmpty) return;

      final data = <String, dynamic>{
        'actorId': effectiveActorId,
        'action': action,
        'targetCollection': targetCollection,
        'targetId': targetId,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (actorId.isNotEmpty && actorId != effectiveActorId) {
        data['subjectUserId'] = actorId;
      }

      await _db.collection('auditLogs').add(data);
    } catch (e) {
      debugPrint('AuditLogService.record failed: $e');
    }
  }
}
