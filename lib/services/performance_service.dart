import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance_model.dart';
import '../models/attendance_model.dart';
import 'audit_log_service.dart';

class AutoScoresResult {
  final double attendanceScore;
  final double punctualityScore;
  final double kpiScore;

  AutoScoresResult({
    required this.attendanceScore,
    required this.punctualityScore,
    required this.kpiScore,
  });
}

class PerformanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Calculate auto attendance and punctuality scores for an employee in a given month
  Future<AutoScoresResult> calculateAutoScores(
    String userId,
    String monthKey,
  ) async {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final nextMonthStr = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    // Query attendance records for that month
    final attendanceSnap = await _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: '$monthKey-01')
        .where('date', isLessThan: nextMonthStr)
        .get();

    final logs = attendanceSnap.docs
        .map((doc) => AttendanceModel.fromFirestore(doc))
        .toList();
    final kpiScore = await _loadKpiScore(userId, monthKey);

    if (logs.isEmpty) {
      return AutoScoresResult(
        attendanceScore: 100.0,
        punctualityScore: 100.0,
        kpiScore: kpiScore,
      );
    }

    int totalAbsents = 0;
    int totalLates = 0;

    for (var log in logs) {
      if (log.status == 'absent') {
        totalAbsents++;
      } else if (log.status == 'late' || log.isLate) {
        totalLates++;
      }
    }

    // Formulas:
    // Attendance Score: starts at 100%, deduct 10% per unexcused absence
    double attendanceScore = 100.0 - (totalAbsents * 10.0);
    if (attendanceScore < 0.0) attendanceScore = 0.0;

    // Punctuality Score: starts at 100%, deduct 5% per late arrival
    double punctualityScore = 100.0 - (totalLates * 5.0);
    if (punctualityScore < 0.0) punctualityScore = 0.0;

    return AutoScoresResult(
      attendanceScore: attendanceScore,
      punctualityScore: punctualityScore,
      kpiScore: kpiScore,
    );
  }

  Future<double> _loadKpiScore(String userId, String monthKey) async {
    try {
      final snap = await _db
          .collection('employeeKpis')
          .where('userId', isEqualTo: userId)
          .where('monthKey', isEqualTo: monthKey)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return 80.0;
      return (snap.docs.first.data()['overallProgress'] as num?)?.toDouble() ??
          80.0;
    } catch (_) {
      return 80.0;
    }
  }

  // Calculate overall grade letter based on weighted scores
  String calculateGradeLetter(double overallScore) {
    if (overallScore >= 90.0) return 'A';
    if (overallScore >= 80.0) return 'B';
    if (overallScore >= 70.0) return 'C';
    if (overallScore >= 60.0) return 'D';
    return 'F';
  }

  // Publish/Update performance evaluation (Overwrite if already graded this month)
  Future<void> publishEvaluation(PerformanceModel req) async {
    final docId = '${req.userId}_${req.monthKey}';
    final docRef = _db.collection('performance').doc(docId);

    final finalModel = PerformanceModel(
      performanceId: docId,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      monthKey: req.monthKey,
      attendanceScore: req.attendanceScore,
      punctualityScore: req.punctualityScore,
      qualityScore: req.qualityScore,
      teamworkScore: req.teamworkScore,
      commitmentScore: req.commitmentScore,
      overallScore: req.overallScore,
      grade: req.grade,
      comments: req.comments,
      publishedAt: DateTime.now(),
      managerId: req.managerId,
    );

    await docRef.set(finalModel.toFirestore());

    await AuditLogService.instance.record(
      actorId: req.managerId,
      action: 'performance_published',
      targetCollection: 'performance',
      targetId: docId,
      metadata: {
        'userId': req.userId,
        'monthKey': req.monthKey,
        'grade': req.grade,
        'overallScore': req.overallScore,
      },
    );

    // Notify employee
    try {
      await _createNotification(
        recipientId: req.userId,
        type: 'performance_published',
        title: 'تم نشر تقييم الأداء الشهري 🏆',
        body:
            'قام مديرك المباشر بنشر تقييم أدائك لشهر ${req.monthKey}. التقييم العام: ${req.grade}',
        data: {'performanceId': docId},
      );
    } catch (_) {}
  }

  // Stream current user's performance history
  Stream<List<PerformanceModel>> watchUserPerformanceHistory(String userId) {
    return _db
        .collection('performance')
        .where('userId', isEqualTo: userId)
        .orderBy('monthKey', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PerformanceModel.fromFirestore(doc))
              .toList();
        });
  }

  // Private Helper to create notification records
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
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
