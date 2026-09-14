import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/payroll_cycle.dart';

final class TeamLeaderboardMember {
  const TeamLeaderboardMember({
    required this.name,
    required this.department,
    this.commitmentScore = 100.0,
  });

  final String name;
  final String department;
  final double commitmentScore;
}

final class TeamLeaderboardService {
  TeamLeaderboardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<TeamLeaderboardMember>> watchActiveMembers({String? monthKey}) {
    final effectiveMonthKey = monthKey ?? PayrollCycle.keyFor(DateTime.now());

    return _firestore
        .collection('productivityScores')
        .where('monthKey', isEqualTo: effectiveMonthKey)
        .limit(20)
        .snapshots()
        .map((scoresSnapshot) {
          if (scoresSnapshot.docs.isNotEmpty) {
            final members = scoresSnapshot.docs
                .map((doc) {
                  final data = doc.data();
                  final rawScore =
                      (data['overallScore'] as num?)?.toDouble() ??
                      (data['attendanceScore'] as num?)?.toDouble() ??
                      (data['punctualityScore'] as num?)?.toDouble() ??
                      0.0;
                  return TeamLeaderboardMember(
                    name:
                        data['employeeName']?.toString() ??
                        data['name']?.toString() ??
                        'موظف متميز',
                    department: data['department']?.toString() ?? 'عام',
                    commitmentScore: rawScore.clamp(0.0, 100.0),
                  );
                })
                .where((m) => m.commitmentScore > 0)
                .toList(growable: true);

            if (members.isNotEmpty) {
              members.sort(
                (a, b) => b.commitmentScore.compareTo(a.commitmentScore),
              );
              return members.take(10).toList(growable: false);
            }
          }

          return const <TeamLeaderboardMember>[];
        });
  }
}
