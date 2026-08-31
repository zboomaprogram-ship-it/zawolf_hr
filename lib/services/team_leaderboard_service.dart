import 'package:cloud_firestore/cloud_firestore.dart';

final class TeamLeaderboardMember {
  const TeamLeaderboardMember({required this.name, required this.department});

  final String name;
  final String department;
}

final class TeamLeaderboardService {
  TeamLeaderboardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<TeamLeaderboardMember>> watchActiveMembers() => _firestore
      .collection('users')
      .where('isActive', isEqualTo: true)
      .limit(5)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => TeamLeaderboardMember(
                name:
                    doc.data()['displayName']?.toString() ??
                    doc.data()['name']?.toString() ??
                    'موظف متميز',
                department: doc.data()['department']?.toString() ?? 'عام',
              ),
            )
            .toList(growable: false),
      );
}
