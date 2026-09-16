import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/pending_early_leave/pending_early_leave.dart';

void main() {
  group('EarlyLeaveDeductionPolicy', () {
    test('maps one through four requested hours to quarter-day steps', () {
      expect(EarlyLeaveDeductionPolicy.dayFraction(60), 0.25);
      expect(EarlyLeaveDeductionPolicy.dayFraction(120), 0.5);
      expect(EarlyLeaveDeductionPolicy.dayFraction(180), 0.75);
      expect(EarlyLeaveDeductionPolicy.dayFraction(240), 1);
    });

    test('rejects partial and out-of-range durations', () {
      expect(
        () => EarlyLeaveDeductionPolicy.dayFraction(30),
        throwsArgumentError,
      );
      expect(
        () => EarlyLeaveDeductionPolicy.dayFraction(300),
        throwsArgumentError,
      );
    });
  });

  test(
    'pending checkout is available at the requested time with exact warning',
    () {
      final normalEnd = DateTime(2026, 9, 16, 17);
      final eligibility = EarlyLeaveCheckoutEligibility(
        permissionId: 'permission-1',
        requestState: EarlyLeaveRequestState.pendingManager,
        requestedCheckoutAt: normalEnd.subtract(const Duration(hours: 2)),
        normalCheckoutAt: normalEnd,
        requestedMinutes: 120,
      );

      expect(eligibility.canCheckoutAt(DateTime(2026, 9, 16, 14, 59)), isFalse);
      expect(eligibility.canCheckoutAt(DateTime(2026, 9, 16, 15)), isTrue);
      expect(eligibility.warningArabic, contains('نصف يوم'));
      expect(eligibility.warningArabic, contains('قيد المراجعة'));
    },
  );
}
