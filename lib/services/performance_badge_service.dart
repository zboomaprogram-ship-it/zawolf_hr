import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/custom_badge_model.dart';

final class PerformanceBadgeRecipient {
  const PerformanceBadgeRecipient({
    required this.uid,
    required this.displayName,
    required this.employeeId,
    required this.department,
    required this.badgeIds,
  });

  final String uid;
  final String displayName;
  final String employeeId;
  final String department;
  final List<String> badgeIds;
}

final class PerformanceBadgeService {
  PerformanceBadgeService._();

  static final instance = PerformanceBadgeService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Set<String>> watchAwardedBadgeIds(String userId) => _db
      .collection('users')
      .doc(userId)
      .snapshots()
      .map(
        (doc) =>
            (doc.data()?['performanceBadgeIds'] as List?)
                ?.whereType<String>()
                .toSet() ??
            const <String>{},
      );

  Stream<List<CustomBadgeModel>> watchCustomBadges() => _db
      .collection('custom_badges')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(CustomBadgeModel.fromFirestore).toList(),
      );

  Future<void> createCustomBadge({
    required String title,
    required String description,
    required String iconName,
    required String colorHex,
    required String targetGoalType,
    required int targetGoalValue,
    required String creatorId,
    required String creatorName,
  }) async {
    final docRef = _db.collection('custom_badges').doc();
    final badge = CustomBadgeModel(
      id: docRef.id,
      title: title,
      description: description,
      iconName: iconName,
      colorHex: colorHex,
      targetGoalType: targetGoalType,
      targetGoalValue: targetGoalValue,
      createdBy: creatorId,
      createdByName: creatorName,
    );
    await docRef.set(badge.toFirestore());
  }

  Future<void> awardBadgeToEmployee({
    required String targetUserId,
    required String badgeId,
  }) async {
    await _db.collection('users').doc(targetUserId).update({
      'performanceBadgeIds': FieldValue.arrayUnion([badgeId]),
    });
  }

  Future<void> removeBadgeFromEmployee({
    required String targetUserId,
    required String badgeId,
  }) async {
    await _db.collection('users').doc(targetUserId).update({
      'performanceBadgeIds': FieldValue.arrayRemove([badgeId]),
    });
  }

  Future<void> markCelebrationBadgeAsSeen({
    required String userId,
    required String badgeId,
  }) async {
    await _db.collection('users').doc(userId).update({
      'seenCelebrationBadgeIds': FieldValue.arrayUnion([badgeId]),
    });
  }

  Future<void> shareBadgeToDepartmentChat({
    required String senderId,
    required String senderName,
    required String department,
    required String badgeTitle,
    required String badgeDescription,
  }) async {
    final deptKey = department.trim().isEmpty ? 'general' : department.trim();
    final chatRef = _db
        .collection('conversations')
        .doc('department_$deptKey')
        .collection('messages');

    await chatRef.add({
      'senderId': senderId,
      'senderName': senderName,
      'content':
          '🎉 مبروك! حصل الموظف ($senderName) على شارة التميز: [$badgeTitle] - $badgeDescription 🏆',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'badge_award',
    });
  }

  Stream<List<PerformanceBadgeRecipient>> watchVisibleRecipients({
    required String viewerId,
    required bool canViewAll,
  }) {
    final query =
        canViewAll
            ? _db.collection('users')
            : _db
                .collection('users')
                .where('managerIds', arrayContains: viewerId);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) {
            final data = doc.data();
            return PerformanceBadgeRecipient(
              uid: doc.id,
              displayName: data['displayName'] as String? ?? 'موظف',
              employeeId: data['employeeId'] as String? ?? '—',
              department: data['department'] as String? ?? '—',
              badgeIds:
                  (data['performanceBadgeIds'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                  const <String>[],
            );
          })
          .where((recipient) => recipient.badgeIds.isNotEmpty)
          .toList(growable: false),
    );
  }
}
