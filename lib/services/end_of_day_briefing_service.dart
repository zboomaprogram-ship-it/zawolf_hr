import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final class EndOfDayBriefing {
  const EndOfDayBriefing({
    required this.presentCount,
    required this.lateCount,
    required this.totalEmployees,
    required this.resolvedTicketsCount,
    required this.tomorrowLeavesCount,
  });

  final int presentCount;
  final int lateCount;
  final int totalEmployees;
  final int resolvedTicketsCount;
  final int tomorrowLeavesCount;
}

final class EndOfDayBriefingService {
  EndOfDayBriefingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<EndOfDayBriefing> load({
    required bool isHr,
    String? managerUid,
  }) async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final tomorrowKey = DateFormat(
      'yyyy-MM-dd',
    ).format(today.add(const Duration(days: 1)));
    Query<Map<String, dynamic>> users = _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .limit(1000);
    if (!isHr && managerUid != null && managerUid.isNotEmpty) {
      users = users.where('managerId', isEqualTo: managerUid);
    }
    final results = await Future.wait([
      users.get(),
      _firestore
          .collection('attendance')
          .where('date', isEqualTo: todayKey)
          .limit(2000)
          .get(),
      _firestore
          .collection('it_tickets')
          .where('status', whereIn: const ['resolved', 'closed'])
          .limit(2000)
          .get(),
      _firestore
          .collection('leaves')
          .where('status', isEqualTo: 'approved')
          .limit(2000)
          .get(),
    ]);
    final attendance = results[1].docs;
    final present = attendance.where((doc) {
      final data = doc.data();
      return data['isLate'] != true &&
          !'${data['status'] ?? ''}'.contains('late');
    }).length;
    final late = attendance.length - present;
    final leaves = results[3].docs;
    return EndOfDayBriefing(
      presentCount: present,
      lateCount: late,
      totalEmployees: results[0].docs.length,
      resolvedTicketsCount: results[2].docs.length,
      tomorrowLeavesCount: leaves.where((doc) {
        final data = doc.data();
        return '${data['requestDate'] ?? data['startDate'] ?? ''}' ==
            tomorrowKey;
      }).length,
    );
  }
}
