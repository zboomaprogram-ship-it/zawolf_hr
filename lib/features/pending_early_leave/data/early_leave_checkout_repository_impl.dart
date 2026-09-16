import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/attendance_policy.dart';
import '../../../models/user_model.dart';
import '../../../services/attendance_policy_service.dart';
import '../domain/early_leave_checkout_eligibility.dart';
import '../domain/early_leave_checkout_repository.dart';
import 'early_leave_checkout_wire_model.dart';

final class FirestoreEarlyLeaveCheckoutRepository
    implements EarlyLeaveCheckoutRepository {
  FirestoreEarlyLeaveCheckoutRepository({
    FirebaseFirestore? firestore,
    AttendancePolicyService? policyService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _policyService = policyService ?? AttendancePolicyService();

  final FirebaseFirestore _db;
  final AttendancePolicyService _policyService;

  @override
  Stream<EarlyLeaveCheckoutEligibility?> watchForToday(
    UserModel employee, {
    DateTime? now,
  }) async* {
    final current = now ?? DateTime.now();
    if (!await _isEnabledFor(employee.uid)) {
      yield null;
      return;
    }
    final normalEnd = await _normalEnd(employee, current);
    final dateKey = DateFormat('yyyy-MM-dd').format(current);
    yield* _db
        .collection('permissions')
        .where('userId', isEqualTo: employee.uid)
        .where('requestDate', isEqualTo: dateKey)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => selectEarlyLeaveEligibility(snapshot.docs, normalEnd),
        );
  }

  @override
  Future<EarlyLeaveCheckoutEligibility?> loadForToday(
    UserModel employee, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    if (!await _isEnabledFor(employee.uid)) return null;
    final dateKey = DateFormat('yyyy-MM-dd').format(current);
    final results = await Future.wait([
      _normalEnd(employee, current),
      _db
          .collection('permissions')
          .where('userId', isEqualTo: employee.uid)
          .where('requestDate', isEqualTo: dateKey)
          .limit(20)
          .get(),
    ]);
    final normalEnd = results[0] as DateTime;
    final snapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    return selectEarlyLeaveEligibility(snapshot.docs, normalEnd);
  }

  Future<DateTime> _normalEnd(UserModel employee, DateTime now) async {
    final policy = await _policyService.getPolicyConfig();
    return AttendancePolicy.parseTimeOnDate(
      now,
      employee.workSchedule.endTime ?? policy.defaultEndTime,
    );
  }

  Future<bool> _isEnabledFor(String actorId) async {
    final snapshot =
        await _db.collection('publicConfig').doc('appSecurity').get();
    final flag = snapshot.data()?['pending_early_leave_checkout_v1'];
    if (flag is! Map) return false;
    if (flag['enabled'] != true) return false;
    if (flag['everyone'] == true) return true;
    final actors = flag['actorIds'];
    return actors is List && actors.whereType<String>().contains(actorId);
  }
}

EarlyLeaveCheckoutEligibility? selectEarlyLeaveEligibility(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  DateTime normalEnd,
) => selectEarlyLeaveWireEligibility(
  docs
      .map(EarlyLeaveCheckoutWireModel.fromFirestore)
      .whereType<EarlyLeaveCheckoutWireModel>(),
  normalEnd,
);

EarlyLeaveCheckoutEligibility? selectEarlyLeaveWireEligibility(
  Iterable<EarlyLeaveCheckoutWireModel> items,
  DateTime normalEnd,
) {
  final candidates =
      items.toList()..sort((left, right) {
        final duration = right.durationMinutes.compareTo(left.durationMinutes);
        if (duration != 0) return duration;
        final submitted = (left.submittedAt ?? DateTime(9999)).compareTo(
          right.submittedAt ?? DateTime(9999),
        );
        if (submitted != 0) return submitted;
        return left.id.compareTo(right.id);
      });
  return candidates.isEmpty ? null : candidates.first.toDomain(normalEnd);
}
