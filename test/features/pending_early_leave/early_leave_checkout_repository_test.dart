import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/pending_early_leave/data/early_leave_checkout_repository_impl.dart';
import 'package:zawolf_hr/features/pending_early_leave/data/early_leave_checkout_wire_model.dart';
import 'package:zawolf_hr/features/pending_early_leave/domain/early_leave_checkout_eligibility.dart';

void main() {
  group('EarlyLeaveCheckoutRepository filtering and tie-breaking', () {
    final normalEnd = DateTime(2026, 9, 16, 17);

    test('returns null when candidates list is empty', () {
      final selected = selectEarlyLeaveWireEligibility([], normalEnd);
      expect(selected, isNull);
    });

    test('selects largest requested duration (earliest checkout time)', () {
      final selected = selectEarlyLeaveWireEligibility([
        EarlyLeaveCheckoutWireModel(
          id: 'one-hour',
          status: 'pending_manager',
          durationMinutes: 60,
          submittedAt: DateTime(2026, 9, 16, 8),
        ),
        EarlyLeaveCheckoutWireModel(
          id: 'two-hour',
          status: 'pending_hr',
          durationMinutes: 120,
          submittedAt: DateTime(2026, 9, 16, 9),
        ),
      ], normalEnd);

      expect(selected?.permissionId, 'two-hour');
      expect(selected?.requestedCheckoutAt, DateTime(2026, 9, 16, 15));
      expect(selected?.requestState, EarlyLeaveRequestState.pendingHr);
    });

    test('breaks tie by oldest submission time', () {
      final selected = selectEarlyLeaveWireEligibility([
        EarlyLeaveCheckoutWireModel(
          id: 'newer-submission',
          status: 'pending_manager',
          durationMinutes: 120,
          submittedAt: DateTime(2026, 9, 16, 10),
        ),
        EarlyLeaveCheckoutWireModel(
          id: 'older-submission',
          status: 'pending_manager',
          durationMinutes: 120,
          submittedAt: DateTime(2026, 9, 16, 8),
        ),
      ], normalEnd);

      expect(selected?.permissionId, 'older-submission');
    });

    test('breaks identical submission tie by stable ID lexicographically', () {
      final submitted = DateTime(2026, 9, 16, 8);
      final selected = selectEarlyLeaveWireEligibility([
        EarlyLeaveCheckoutWireModel(
          id: 'z-perm',
          status: 'pending_manager',
          durationMinutes: 120,
          submittedAt: submitted,
        ),
        EarlyLeaveCheckoutWireModel(
          id: 'a-perm',
          status: 'pending_manager',
          durationMinutes: 120,
          submittedAt: submitted,
        ),
      ], normalEnd);

      expect(selected?.permissionId, 'a-perm');
    });
  });
}
