import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/pending_early_leave/data/early_leave_checkout_repository_impl.dart';
import 'package:zawolf_hr/features/pending_early_leave/data/early_leave_checkout_wire_model.dart';

void main() {
  test('selects earliest checkout then oldest submission then stable id', () {
    final normalEnd = DateTime(2026, 9, 16, 17);
    final selected = selectEarlyLeaveWireEligibility([
      EarlyLeaveCheckoutWireModel(
        id: 'later-checkout',
        status: 'pending_manager',
        durationMinutes: 60,
        submittedAt: DateTime(2026, 9, 16, 8),
      ),
      EarlyLeaveCheckoutWireModel(
        id: 'b',
        status: 'pending_hr',
        durationMinutes: 120,
        submittedAt: DateTime(2026, 9, 16, 9),
      ),
      EarlyLeaveCheckoutWireModel(
        id: 'a',
        status: 'rejected',
        durationMinutes: 120,
        submittedAt: DateTime(2026, 9, 16, 9),
      ),
    ], normalEnd);

    expect(selected?.permissionId, 'a');
    expect(selected?.requestedCheckoutAt, DateTime(2026, 9, 16, 15));
  });
}
