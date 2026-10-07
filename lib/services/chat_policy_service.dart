import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_policy.dart';

class ChatPolicyService {
  final FirebaseFirestore _db;

  ChatPolicyService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<ChatPolicyConfig> loadPolicy() async {
    try {
      final compDoc = await _db.collection('companies').doc('zawolf').get();
      if (compDoc.exists) {
        final data = compDoc.data();
        if (data != null && data.containsKey('chatPolicy')) {
          final cp = data['chatPolicy'];
          if (cp is Map<String, dynamic>) {
            return ChatPolicyConfig.fromMap(cp);
          }
        }
      }
      final pubDoc =
          await _db.collection('publicConfig').doc('chatPolicy').get();
      if (pubDoc.exists) {
        return ChatPolicyConfig.fromMap(pubDoc.data());
      }
    } catch (_) {}
    return const ChatPolicyConfig();
  }

  Stream<ChatPolicyConfig> watchPolicy() {
    return _db
        .collection('companies')
        .doc('zawolf')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('chatPolicy')) {
          final cp = data['chatPolicy'];
          if (cp is Map<String, dynamic>) {
            return ChatPolicyConfig.fromMap(cp);
          }
        }
      }
      return const ChatPolicyConfig();
    });
  }

  Future<void> updatePolicy({
    required ChatPolicyConfig policy,
    required String actorId,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('companies').doc('zawolf'),
      {
        'chatPolicy': policy.toMap(),
        'chatPolicyUpdatedAt': FieldValue.serverTimestamp(),
        'chatPolicyUpdatedBy': actorId,
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('publicConfig').doc('chatPolicy'),
      {
        ...policy.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actorId,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
