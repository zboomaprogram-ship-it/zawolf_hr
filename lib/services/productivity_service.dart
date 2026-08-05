import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/kpi_model.dart';
import '../models/productivity_score_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';
import 'attendance_period_summary_service.dart';
import 'managed_employee_service.dart';
import 'role_notification_service.dart';
import '../utils/payroll_cycle.dart';

class ProductivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ManagedEmployeeService _managedEmployees = ManagedEmployeeService();
  final AttendancePeriodSummaryService _attendanceSummary =
      AttendancePeriodSummaryService();

  Stream<ProductivityScoreModel?> watchCachedScore(
    String userId,
    String monthKey,
  ) {
    return _db
        .collection('productivityScores')
        .doc('${userId}_$monthKey')
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? ProductivityScoreModel.fromFirestore(doc) : null,
        );
  }

  Stream<List<ProductivityScoreModel>> watchRanking(
    UserModel reviewer,
    String monthKey,
  ) {
    if (reviewer.role == EmployeeRole.teamLeader) {
      return Stream.fromFuture(
        _managedEmployees.loadForReviewer(reviewer),
      ).asyncExpand((employees) {
        final references = employees
            .map(
              (employee) => _db
                  .collection('productivityScores')
                  .doc('${employee.uid}_$monthKey'),
            )
            .toList();
        return _watchScoreDocuments(references);
      });
    }
    Query<Map<String, dynamic>> query = _db
        .collection('productivityScores')
        .where('monthKey', isEqualTo: monthKey);
    if (reviewer.role == EmployeeRole.manager) {
      return _watchMergedRankings([
        query.where('managerIds', arrayContains: reviewer.uid),
        query.where('managerId', isEqualTo: reviewer.uid),
      ]);
    }
    return query.snapshots().map((snapshot) {
      final scores = snapshot.docs
          .map(ProductivityScoreModel.fromFirestore)
          .toList();
      scores.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      return scores;
    });
  }

  Stream<List<ProductivityScoreModel>> _watchScoreDocuments(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) {
    if (references.isEmpty) return Stream.value(const []);

    late StreamController<List<ProductivityScoreModel>> controller;
    final snapshots = <String, ProductivityScoreModel?>{};
    final loaded = <String>{};
    final subscriptions = <StreamSubscription>[];

    void emit() {
      if (loaded.length != references.length) return;
      final scores =
          snapshots.values.whereType<ProductivityScoreModel>().toList()
            ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
      controller.add(scores);
    }

    controller = StreamController<List<ProductivityScoreModel>>(
      onListen: () {
        for (final reference in references) {
          subscriptions.add(
            reference.snapshots().listen((document) {
              loaded.add(reference.id);
              snapshots[reference.id] = document.exists
                  ? ProductivityScoreModel.fromFirestore(document)
                  : null;
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Stream<List<ProductivityScoreModel>> _watchMergedRankings(
    List<Query<Map<String, dynamic>>> queries,
  ) {
    late StreamController<List<ProductivityScoreModel>> controller;
    final snapshots = List<List<ProductivityScoreModel>?>.filled(
      queries.length,
      null,
    );
    final subscriptions = <StreamSubscription>[];

    void emit() {
      if (snapshots.any((items) => items == null)) return;
      final byId = <String, ProductivityScoreModel>{};
      for (final items in snapshots.whereType<List<ProductivityScoreModel>>()) {
        for (final item in items) {
          byId[item.scoreId] = item;
        }
      }
      final scores = byId.values.toList()
        ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
      controller.add(scores);
    }

    controller = StreamController<List<ProductivityScoreModel>>(
      onListen: () {
        for (var index = 0; index < queries.length; index++) {
          subscriptions.add(
            queries[index].snapshots().listen((snapshot) {
              snapshots[index] = snapshot.docs
                  .map(ProductivityScoreModel.fromFirestore)
                  .toList();
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<ProductivityScoreModel> calculateForUser(
    UserModel user,
    String monthKey,
  ) async {
    final cycle = PayrollCycle.forKey(monthKey);
    final results = await Future.wait([
      _attendanceSummary.loadForUser(
        user: user,
        start: cycle.start,
        end: cycle.end,
      ),
      _db
          .collection('tasks')
          .where('assigneeId', isEqualTo: user.uid)
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cycle.start),
          )
          .where('dueDate', isLessThan: Timestamp.fromDate(cycle.nextStart))
          .get(),
      _db
          .collection('employeeKpis')
          .where('userId', isEqualTo: user.uid)
          .where('monthKey', isEqualTo: monthKey)
          .limit(1)
          .get(),
    ]);

    final attendanceSummary = results[0] as AttendancePeriodSummary;
    final taskDocs = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final kpiDocs = results[2] as QuerySnapshot<Map<String, dynamic>>;

    final tasks = taskDocs.docs.map(EmployeeTaskModel.fromFirestore).toList();
    final kpi = kpiDocs.docs.isEmpty
        ? null
        : EmployeeKpiModel.fromFirestore(kpiDocs.docs.first);

    final absentDays = attendanceSummary.absentDays;
    final lateDays = attendanceSummary.lateDays;
    final expectedDays = attendanceSummary.expectedDays;
    final attendanceScore = expectedDays == 0
        ? 100.0
        : ((expectedDays - absentDays) / expectedDays * 100)
              .clamp(0, 100)
              .toDouble();
    final attendedDays = attendanceSummary.presentDays;
    final punctualityScore = attendedDays == 0
        ? 100.0
        : ((attendedDays - lateDays) / attendedDays * 100)
              .clamp(0, 100)
              .toDouble();

    final activeTasks = tasks
        .where((task) => task.status != TaskStatus.cancelled)
        .toList();
    final completedTasks = activeTasks
        .where((task) => task.status == TaskStatus.done)
        .length;
    final overdueTasks = activeTasks.where((task) {
      return task.status == TaskStatus.late ||
          (DateTime.now().isAfter(task.dueDate) &&
              task.status != TaskStatus.done);
    }).length;
    final hasTaskData = activeTasks.isNotEmpty;
    final taskCompletionScore = activeTasks.isEmpty
        ? 0.0
        : ((completedTasks / activeTasks.length) * 100)
              .clamp(0, 100)
              .toDouble();
    final reviewedTasks = activeTasks
        .where((task) => task.qualityScore != null)
        .toList();
    final hasTaskQualityData = reviewedTasks.isNotEmpty;
    final taskQualityScore = reviewedTasks.isEmpty
        ? 0.0
        : (reviewedTasks.fold<double>(
                    0,
                    (total, task) => total + (task.qualityScore ?? 0),
                  ) /
                  reviewedTasks.length)
              .clamp(0, 100)
              .toDouble();
    final hasKpiData = kpi != null;
    final kpiScore = (kpi?.overallProgress ?? 0).clamp(0, 100).toDouble();
    final existingScore = await _db
        .collection('productivityScores')
        .doc('${user.uid}_$monthKey')
        .get();
    final behaviorScore =
        (existingScore.data()?['behaviorScore'] as num?)?.toDouble() ?? 100;
    final overall = ProductivityScoreModel.calculateAvailableOverall(
      attendanceScore: attendanceScore,
      punctualityScore: punctualityScore,
      taskCompletionScore: hasTaskData ? taskCompletionScore : null,
      taskQualityScore: hasTaskQualityData ? taskQualityScore : null,
      kpiScore: hasKpiData ? kpiScore : null,
      behaviorScore: behaviorScore,
      hasKpiData: hasKpiData,
    );

    return ProductivityScoreModel(
      scoreId: '${user.uid}_$monthKey',
      userId: user.uid,
      employeeId: user.employeeId,
      employeeName: user.displayName,
      department: user.department,
      managerId: user.managerId ?? '',
      managerIds: user.managerIds.isNotEmpty
          ? user.managerIds
          : [if ((user.managerId ?? '').isNotEmpty) user.managerId!],
      monthKey: monthKey,
      attendanceScore: attendanceScore,
      punctualityScore: punctualityScore,
      taskCompletionScore: taskCompletionScore,
      taskQualityScore: taskQualityScore,
      kpiScore: kpiScore,
      behaviorScore: behaviorScore,
      hasTaskData: hasTaskData,
      hasTaskQualityData: hasTaskQualityData,
      hasKpiData: hasKpiData,
      overallScore: overall,
      completedTasks: completedTasks,
      totalTasks: activeTasks.length,
      overdueTasks: overdueTasks,
      absentDays: absentDays,
      lateDays: lateDays,
    );
  }

  Future<void> calculateAndCacheForUser({
    required UserModel user,
    required String monthKey,
    required String actorId,
  }) async {
    final score = await calculateForUser(user, monthKey);
    await _db
        .collection('productivityScores')
        .doc(score.scoreId)
        .set(score.toFirestore(), SetOptions(merge: true));
    await AuditLogService.instance.record(
      actorId: actorId,
      action: 'productivity_score_calculated',
      targetCollection: 'productivityScores',
      targetId: score.scoreId,
      metadata: {
        'userId': user.uid,
        'monthKey': monthKey,
        'overallScore': score.overallScore,
      },
    );
  }

  Future<void> updateBehaviorScore({
    required String employeeUserId,
    required UserModel reviewer,
    required String monthKey,
    required double behaviorScore,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (behaviorScore < 0 || behaviorScore > 100) {
      throw ArgumentError('Behavior score must be between 0 and 100.');
    }
    if (normalizedReason.length < 3) {
      throw ArgumentError('A behavior adjustment reason is required.');
    }

    final managed = await _managedEmployees.loadForReviewer(reviewer);
    final employee = managed.cast<UserModel?>().firstWhere(
      (user) => user?.uid == employeeUserId,
      orElse: () => null,
    );
    if (employee == null) {
      throw StateError('You cannot edit this employee.');
    }

    final ref = _db
        .collection('productivityScores')
        .doc('${employee.uid}_$monthKey');
    var snapshot = await ref.get();
    if (!snapshot.exists) {
      await calculateAndCacheForUser(
        user: employee,
        monthKey: monthKey,
        actorId: reviewer.uid,
      );
      snapshot = await ref.get();
    }
    if (!snapshot.exists) {
      throw StateError('Productivity score is unavailable.');
    }

    final current = ProductivityScoreModel.fromFirestore(snapshot);
    final overall = ProductivityScoreModel.calculateAvailableOverall(
      attendanceScore: current.attendanceScore,
      punctualityScore: current.punctualityScore,
      kpiScore: current.hasKpiData ? current.kpiScore : null,
      behaviorScore: behaviorScore,
    );
    await ref.update({
      'behaviorScore': behaviorScore,
      'overallScore': overall,
      'behaviorUpdatedBy': reviewer.uid,
      'behaviorUpdatedName': reviewer.displayName,
      'behaviorReason': normalizedReason,
      'behaviorUpdatedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'productivity_behavior_adjusted',
      targetCollection: 'productivityScores',
      targetId: ref.id,
      metadata: {
        'userId': employee.uid,
        'monthKey': monthKey,
        'behaviorScore': behaviorScore,
        'reason': normalizedReason,
      },
    );
    await RoleNotificationService.instance.createNotification(
      recipientId: employee.uid,
      type: 'productivity_behavior_updated',
      title: 'تحديث تقييم السلوك',
      body:
          'تم تحديث تقييم السلوك إلى ${behaviorScore.toStringAsFixed(0)}%. السبب: $normalizedReason',
      data: {'monthKey': monthKey, 'userId': employee.uid},
    );
  }

  Future<int> refreshRanking(UserModel reviewer, String monthKey) async {
    final users = await _managedEmployees.loadForReviewer(reviewer);

    // Keep concurrency bounded: much faster than a fully sequential refresh,
    // without creating a burst large enough to overwhelm Firestore.
    const batchSize = 4;
    for (var offset = 0; offset < users.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, users.length);
      await Future.wait(
        users
            .sublist(offset, end)
            .map(
              (user) => calculateAndCacheForUser(
                user: user,
                monthKey: monthKey,
                actorId: reviewer.uid,
              ),
            ),
      );
    }
    return users.length;
  }
}
