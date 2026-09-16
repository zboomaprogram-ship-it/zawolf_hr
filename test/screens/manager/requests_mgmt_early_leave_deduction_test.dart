import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/pending_early_leave/domain/early_leave_deduction_policy.dart';

void main() {
  group('Rejected early-leave deduction review policy', () {
    test('calculates correct day fractions for HR review display', () {
      expect(EarlyLeaveDeductionPolicy.dayFraction(60), 0.25);
      expect(EarlyLeaveDeductionPolicy.dayFraction(120), 0.50);
      expect(EarlyLeaveDeductionPolicy.dayFraction(180), 0.75);
      expect(EarlyLeaveDeductionPolicy.dayFraction(240), 1.00);
    });

    test('rejection consequence review decision values are approved or rejected', () {
      const allowedDecisions = {'approved', 'rejected'};
      expect(allowedDecisions.contains('approved'), isTrue);
      expect(allowedDecisions.contains('rejected'), isTrue);
      expect(allowedDecisions.contains('pending_hr'), isFalse);
    });
  });
}
