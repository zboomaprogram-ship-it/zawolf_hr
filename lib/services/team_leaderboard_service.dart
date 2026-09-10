import 'package:cloud_firestore/cloud_firestore.dart';

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

  Stream<List<TeamLeaderboardMember>> watchActiveMembers() => _firestore
      .collection('users')
      .where('isActive', isEqualTo: true)
      .limit(10)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) {
                final data = doc.data();
                final rawScore =
                    (data['disciplineScore'] as num?)?.toDouble() ??
                    (data['productivityScore'] as num?)?.toDouble() ??
                    (data['attendanceRate'] as num?)?.toDouble() ??
                    100.0;
                return TeamLeaderboardMember(
                  name:
                      data['displayName']?.toString() ??
                      data['name']?.toString() ??
                      'موظف متميز',
                  department: data['department']?.toString() ?? 'عام',
                  commitmentScore: rawScore.clamp(0.0, 100.0),
                );
              },
            )
            .toList(growable: false),
      );
}
