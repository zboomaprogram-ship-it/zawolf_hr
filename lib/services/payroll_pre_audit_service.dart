import 'package:cloud_firestore/cloud_firestore.dart';

final class PayrollPreAuditSummary {
  const PayrollPreAuditSummary({
    required this.pendingLeaves,
    required this.pendingPermissions,
    required this.pendingCorrections,
    required this.unassignedSalaryEmployees,
  });

  final int pendingLeaves;
  final int pendingPermissions;
  final int pendingCorrections;
  final int unassignedSalaryEmployees;

  bool get hasIssues =>
      pendingLeaves > 0 ||
      pendingPermissions > 0 ||
      pendingCorrections > 0 ||
      unassignedSalaryEmployees > 0;
}

final class PayrollPreAuditService {
  PayrollPreAuditService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<PayrollPreAuditSummary> load() async {
    final results = await Future.wait([
      _pending('leaves'),
      _pending('permissions'),
      _pending('attendanceCorrections'),
      _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .limit(1000)
          .get(),
    ]);
    final users = results[3];
    final withoutSalary = users.docs
        .where(
          (doc) => ((doc.data()['baseSalary'] as num?)?.toDouble() ?? 0) <= 0,
        )
        .length;
    return PayrollPreAuditSummary(
      pendingLeaves: results[0].docs.length,
      pendingPermissions: results[1].docs.length,
      pendingCorrections: results[2].docs.length,
      unassignedSalaryEmployees: withoutSalary,
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _pending(String collection) =>
      _firestore
          .collection(collection)
          .where(
            'status',
            whereIn: const ['pending_manager', 'pending_hr', 'pending'],
          )
          .limit(1000)
          .get();
}
