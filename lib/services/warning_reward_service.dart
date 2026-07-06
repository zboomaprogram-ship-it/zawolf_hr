import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/productivity_score_model.dart';
import '../models/user_model.dart';
import '../models/warning_reward_model.dart';
import 'audit_log_service.dart';

class WarningRewardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<WarningRewardModel>> watchMyRecords(String userId) {
    return _db
        .collection('warningsRewards')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Stream<List<WarningRewardModel>> watchManagedRecords(UserModel reviewer) {
    Query<Map<String, dynamic>> query = _db.collection('warningsRewards');
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Future<List<UserModel>> loadAssignableEmployees(UserModel reviewer) async {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isActive', isEqualTo: true);
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    final snap = await query.get();
    final users = snap.docs.map(UserModel.fromFirestore).where((user) {
      if (user.role == EmployeeRole.superAdmin) return false;
      if (reviewer.role == EmployeeRole.manager) {
        return user.managerId == reviewer.uid;
      }
      return true;
    }).toList();
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }

  Future<void> createRecord({
    required UserModel creator,
    required UserModel employee,
    required String type,
    required String title,
    required String description,
    String status = WarningRewardStatus.issued,
    String source = 'manual',
    String? monthKey,
    double? productivityScore,
    double amount = 0,
    String currency = 'EGP',
  }) async {
    final ref = _db.collection('warningsRewards').doc();
    final record = WarningRewardModel(
      recordId: ref.id,
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      managerId: employee.managerId ?? creator.uid,
      type: type,
      status: status,
      title: title.trim(),
      description: description.trim(),
      createdBy: creator.uid,
      createdByName: creator.displayName,
      source: source,
      monthKey: monthKey,
      productivityScore: productivityScore,
      amount: amount,
      currency: currency,
    );

    await ref.set(record.toFirestore());
    await AuditLogService.instance.record(
      actorId: creator.uid,
      action: 'warning_reward_created',
      targetCollection: 'warningsRewards',
      targetId: ref.id,
      metadata: {
        'userId': employee.uid,
        'type': type,
        'status': status,
        'source': source,
        'amount': amount,
      },
    );

    if (status == WarningRewardStatus.issued) {
      try {
        await _createNotification(
          recipientId: employee.uid,
          type: 'warning_reward_created',
          title: WarningRewardType.arabicLabel(type),
          body: title.trim(),
          data: {'recordId': ref.id},
        );
      } catch (_) {}
    }
  }

  Future<int> generateSuggestions({
    required UserModel reviewer,
    required String monthKey,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('productivityScores')
        .where('monthKey', isEqualTo: monthKey);
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    final scoresSnap = await query.get();
    var created = 0;

    for (final doc in scoresSnap.docs) {
      final score = ProductivityScoreModel.fromFirestore(doc);
      final suggestion = _suggestionForScore(score);
      if (suggestion == null) continue;

      final existing = await _db
          .collection('warningsRewards')
          .where('userId', isEqualTo: score.userId)
          .where('monthKey', isEqualTo: monthKey)
          .where('type', isEqualTo: suggestion.type)
          .where('source', isEqualTo: 'productivity_auto')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final userDoc = await _db.collection('users').doc(score.userId).get();
      if (!userDoc.exists) continue;
      final employee = UserModel.fromFirestore(userDoc);
      await createRecord(
        creator: reviewer,
        employee: employee,
        type: suggestion.type,
        title: suggestion.title,
        description: suggestion.description,
        status: WarningRewardStatus.suggested,
        source: 'productivity_auto',
        monthKey: monthKey,
        productivityScore: score.overallScore,
      );
      created++;
    }

    return created;
  }

  Future<void> issueSuggestedRecord(String recordId, UserModel reviewer) async {
    final ref = _db.collection('warningsRewards').doc(recordId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('السجل غير موجود');
    final record = WarningRewardModel.fromFirestore(doc);

    await ref.update({'status': WarningRewardStatus.issued});
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'warning_reward_issued',
      targetCollection: 'warningsRewards',
      targetId: recordId,
      metadata: {'userId': record.userId, 'type': record.type},
    );

    try {
      await _createNotification(
        recipientId: record.userId,
        type: 'warning_reward_created',
        title: WarningRewardType.arabicLabel(record.type),
        body: record.title,
        data: {'recordId': recordId},
      );
    } catch (_) {}
  }

  Future<void> dismissSuggestion(String recordId, UserModel reviewer) async {
    await _db.collection('warningsRewards').doc(recordId).update({
      'status': WarningRewardStatus.dismissed,
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'warning_reward_dismissed',
      targetCollection: 'warningsRewards',
      targetId: recordId,
    );
  }

  Future<void> acknowledge(String recordId, String userId) async {
    await _db.collection('warningsRewards').doc(recordId).update({
      'status': WarningRewardStatus.acknowledged,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: userId,
      action: 'warning_reward_acknowledged',
      targetCollection: 'warningsRewards',
      targetId: recordId,
    );
  }

  _AutoSuggestion? _suggestionForScore(ProductivityScoreModel score) {
    if (score.overallScore < 60) {
      return _AutoSuggestion(
        type: WarningRewardType.warning,
        title: 'اقتراح إنذار بسبب انخفاض الإنتاجية',
        description:
            'إنتاجية ${score.employeeName} لشهر ${score.monthKey} وصلت إلى ${score.overallScore.toStringAsFixed(1)}%. يوصى بمراجعة الأداء وإصدار إنذار إذا لم يوجد سبب مقبول.',
      );
    }
    if (score.overallScore < 70) {
      return _AutoSuggestion(
        type: WarningRewardType.followUp,
        title: 'اقتراح اجتماع متابعة',
        description:
            'إنتاجية ${score.employeeName} أقل من المستوى المطلوب. يوصى باجتماع متابعة وخطة تحسين قصيرة.',
      );
    }
    if (score.overallScore >= 90) {
      return _AutoSuggestion(
        type: WarningRewardType.reward,
        title: 'اقتراح مكافأة أداء',
        description:
            'إنتاجية ${score.employeeName} مرتفعة هذا الشهر (${score.overallScore.toStringAsFixed(1)}%). يوصى بمكافأة أو تقدير.',
      );
    }
    return null;
  }

  List<WarningRewardModel> _recordsFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map(WarningRewardModel.fromFirestore).toList();
  }

  Future<void> _createNotification({
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
}

class _AutoSuggestion {
  final String type;
  final String title;
  final String description;

  const _AutoSuggestion({
    required this.type,
    required this.title,
    required this.description,
  });
}
