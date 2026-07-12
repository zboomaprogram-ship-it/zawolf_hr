import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/suggestion_model.dart';
import '../models/user_model.dart';
import 'role_notification_service.dart';

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

    try {
      await _notifyManagers(
        title: 'مقترح جديد',
        body: '${employee.displayName} أرسل مقترحاً: ${title.trim()}',
        suggestionId: ref.id,
      );
    } catch (_) {}
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
    await RoleNotificationService.instance.notifyRole(
      role: 'manager',
      type: 'suggestion_new',
      title: title,
      body: body,
      data: {'suggestionId': suggestionId},
    );
  }
}
