import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../models/employee_role.dart';
import '../models/kpi_model.dart';
import '../models/productivity_score_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';
import '../utils/payroll_cycle.dart';

class ProductivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    Query<Map<String, dynamic>> query = _db
        .collection('productivityScores')
        .where('monthKey', isEqualTo: monthKey);
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    return query.snapshots().map((snapshot) {
      final scores = snapshot.docs
          .map(ProductivityScoreModel.fromFirestore)
          .toList();
      scores.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      return scores;
    });
  }

  Future<ProductivityScoreModel> calculateForUser(
    UserModel user,
    String monthKey,
  ) async {
    final cycle = PayrollCycle.forKey(monthKey);
    final results = await Future.wait([
      _db
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: cycle.startDateKey)
          .where('date', isLessThan: cycle.nextStartDateKey)
          .get(),
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

    final attendanceDocs = results[0];
    final taskDocs = results[1];
    final kpiDocs = results[2];

    final attendance = attendanceDocs.docs
        .map((doc) => AttendanceModel.fromFirestore(doc))
        .toList();
    final tasks = taskDocs.docs.map(EmployeeTaskModel.fromFirestore).toList();
    final kpi = kpiDocs.docs.isEmpty
        ? null
        : EmployeeKpiModel.fromFirestore(kpiDocs.docs.first);

    final absentDays = attendance
        .where((item) => item.status == 'absent')
        .length;
    final lateDays = attendance
        .where((item) => item.isLate || item.status == 'late')
        .length;
    final attendanceScore = (100 - (absentDays * 10)).clamp(0, 100).toDouble();
    final punctualityScore = (100 - (lateDays * 5)).clamp(0, 100).toDouble();

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
    final taskCompletionScore = activeTasks.isEmpty
        ? 80.0
        : ((completedTasks / activeTasks.length) * 100)
              .clamp(0, 100)
              .toDouble();
    final reviewedTasks = activeTasks
        .where((task) => task.qualityScore != null)
        .toList();
    final taskQualityScore = reviewedTasks.isEmpty
        ? 80.0
        : (reviewedTasks.fold<double>(
                    0,
                    (total, task) => total + (task.qualityScore ?? 0),
                  ) /
                  reviewedTasks.length)
              .clamp(0, 100)
              .toDouble();
    final kpiScore = (kpi?.overallProgress ?? 80).clamp(0, 100).toDouble();
    final overall = ProductivityScoreModel.calculateOverall(
      attendanceScore: attendanceScore,
      punctualityScore: punctualityScore,
      taskCompletionScore: taskCompletionScore,
      taskQualityScore: taskQualityScore,
      kpiScore: kpiScore,
    );

    return ProductivityScoreModel(
      scoreId: '${user.uid}_$monthKey',
      userId: user.uid,
      employeeId: user.employeeId,
      employeeName: user.displayName,
      department: user.department,
      managerId: user.managerId ?? '',
      monthKey: monthKey,
      attendanceScore: attendanceScore,
      punctualityScore: punctualityScore,
      taskCompletionScore: taskCompletionScore,
      taskQualityScore: taskQualityScore,
      kpiScore: kpiScore,
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
        .set(score.toFirestore());
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

  Future<int> refreshRanking(UserModel reviewer, String monthKey) async {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isActive', isEqualTo: true);
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    final usersSnap = await query.get();
    final users = usersSnap.docs.map(UserModel.fromFirestore).where((user) {
      if (user.role == EmployeeRole.superAdmin) return false;
      if (reviewer.role == EmployeeRole.manager) {
        return user.managerId == reviewer.uid;
      }
      return true;
    }).toList();

    for (final user in users) {
      await calculateAndCacheForUser(
        user: user,
        monthKey: monthKey,
        actorId: reviewer.uid,
      );
    }
    return users.length;
  }
}
