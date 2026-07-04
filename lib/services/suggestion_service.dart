import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/suggestion_model.dart';
import '../models/user_model.dart';
import 'onesignal_service.dart';

class SuggestionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> submitSuggestion({
    required UserModel employee,
    required String title,
    required String body,
  }) async {
    final ref = _db.collection('suggestions').doc();
    await ref.set(
      SuggestionModel(
        suggestionId: ref.id,
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        department: employee.department,
        title: title.trim(),
        body: body.trim(),
        status: 'new',
      ).toFirestore(),
    );

    await _notifyManagers(
      title: 'مقترح جديد',
      body: '${employee.displayName} أرسل مقترحاً: ${title.trim()}',
      suggestionId: ref.id,
    );
  }

  Stream<List<SuggestionModel>> watchMySuggestions(String userId) {
    return _db
        .collection('suggestions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(_sortedSuggestions);
  }

  Stream<List<SuggestionModel>> watchAllSuggestions() {
    return _db.collection('suggestions').snapshots().map(_sortedSuggestions);
  }

  Future<void> markReviewed(String suggestionId, String reviewerId) async {
    await _db.collection('suggestions').doc(suggestionId).update({
      'status': 'reviewed',
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  List<SuggestionModel> _sortedSuggestions(QuerySnapshot snapshot) {
    final suggestions = snapshot.docs
        .map((doc) => SuggestionModel.fromFirestore(doc))
        .toList();
    suggestions.sort((a, b) {
      final aTime = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return suggestions;
  }

  Future<void> _notifyManagers({
    required String title,
    required String body,
    required String suggestionId,
  }) async {
    final targets = <String>{};
    for (final role in ['manager', 'super_admin']) {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      targets.addAll(snap.docs.map((doc) => doc.id));
    }

    final batch = _db.batch();
    for (final userId in targets) {
      final notifRef = _db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'type': 'suggestion_new',
        'title': title,
        'body': body,
        'data': {'suggestionId': suggestionId},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection('users').doc(userId), {
        'unreadNotifications': FieldValue.increment(1),
      });
    }
    await batch.commit();

    await OneSignalService.sendPushToUsers(
      targetUids: targets.toList(),
      title: title,
      body: body,
      additionalData: {'suggestionId': suggestionId},
    );
  }
}
