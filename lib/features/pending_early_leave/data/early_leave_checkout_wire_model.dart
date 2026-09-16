import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/early_leave_checkout_eligibility.dart';
import '../domain/early_leave_deduction_policy.dart';

final class EarlyLeaveCheckoutWireModel {
  const EarlyLeaveCheckoutWireModel({
    required this.id,
    required this.status,
    required this.durationMinutes,
    required this.submittedAt,
  });

  final String id;
  final String status;
  final int durationMinutes;
  final DateTime? submittedAt;

  static EarlyLeaveCheckoutWireModel? fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data['permissionType'] != 'early_leave') return null;
    final state = parseEarlyLeaveRequestState('${data['status'] ?? ''}');
    final minutes = (data['durationMinutes'] as num?)?.toInt() ?? 0;
    if (state == null || !EarlyLeaveDeductionPolicy.supports(minutes)) {
      return null;
    }
    return EarlyLeaveCheckoutWireModel(
      id: doc.id,
      status: '${data['status']}',
      durationMinutes: minutes,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
    );
  }

  EarlyLeaveCheckoutEligibility toDomain(DateTime normalCheckoutAt) =>
      EarlyLeaveCheckoutEligibility(
        permissionId: id,
        requestState: parseEarlyLeaveRequestState(status)!,
        requestedCheckoutAt: normalCheckoutAt.subtract(
          Duration(minutes: durationMinutes),
        ),
        normalCheckoutAt: normalCheckoutAt,
        requestedMinutes: durationMinutes,
      );
}
