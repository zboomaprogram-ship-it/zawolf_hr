import 'package:cloud_firestore/cloud_firestore.dart';

class PollService {
  PollService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String> createPoll({
    required String createdBy,
    required String title,
    required String description,
    required List<String> options,
    required List<String> targetUserIds,
  }) async {
    final cleanedOptions = options
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final recipients = targetUserIds.toSet().toList();
    if (title.trim().isEmpty) throw Exception('اكتب عنوان التصويت.');
    if (cleanedOptions.length < 2) throw Exception('أضف خيارين على الأقل.');
    if (recipients.isEmpty) throw Exception('اختر موظفاً واحداً على الأقل.');
    if (recipients.length > 200) {
      throw Exception('الحد الأقصى للتصويت الواحد هو 200 موظف.');
    }

    final pollRef = _db.collection('polls').doc();
    final batch = _db.batch();
    batch.set(pollRef, {
      'pollId': pollRef.id,
      'title': title.trim(),
      'description': description.trim(),
      'options': [
        for (var index = 0; index < cleanedOptions.length; index++)
          {'id': 'option_$index', 'label': cleanedOptions[index]},
      ],
      'targetUserIds': recipients,
      'status': 'open',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final userId in recipients) {
      final notificationRef = _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .doc();
      batch.set(notificationRef, {
        'notificationId': notificationRef.id,
        'type': 'poll_created',
        'title': 'تصويت جديد: ${title.trim()}',
        'body': description.trim().isEmpty
            ? 'شارك برأيك الآن.'
            : description.trim(),
        'data': {'pollId': pollRef.id, 'route': '/polls'},
        'isRead': false,
        'pushSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection('users').doc(userId), {
        'unreadNotifications': FieldValue.increment(1),
      });
    }
    await batch.commit();
    return pollRef.id;
  }

  Future<void> vote({
    required String pollId,
    required String userId,
    required String optionId,
  }) async {
    final pollRef = _db.collection('polls').doc(pollId);
    final voteRef = pollRef.collection('votes').doc(userId);
    await _db.runTransaction((transaction) async {
      final poll = await transaction.get(pollRef);
      if (!poll.exists || poll.data()?['status'] != 'open') {
        throw Exception('هذا التصويت مغلق.');
      }
      final targetIds = List<String>.from(
        poll.data()?['targetUserIds'] as List? ?? const [],
      );
      if (!targetIds.contains(userId)) {
        throw Exception('هذا التصويت غير موجه إلى حسابك.');
      }
      final existing = await transaction.get(voteRef);
      if (existing.exists) throw Exception('تم تسجيل صوتك من قبل.');
      transaction.set(voteRef, {
        'userId': userId,
        'optionId': optionId,
        'votedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> closePoll(String pollId) {
    return _db.collection('polls').doc(pollId).update({'status': 'closed'});
  }
}
