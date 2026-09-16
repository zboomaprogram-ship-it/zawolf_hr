import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/attendance_reconciliation_service.dart';

void main() {
  test('approval never clears an unrelated lateness deduction', () {
    expect(
      shouldClearLegacyEarlyCheckoutDeduction({
        'salaryDeductionCode': 'late_quarter_day',
      }, 'permission-1'),
      isFalse,
    );
  });

  test(
    'approval clears only matching linked legacy early-checkout deduction',
    () {
      final attendance = {
        'salaryDeductionCode': 'early_checkout_quarter_day',
        'earlyLeaveCheckoutEvidence': {'permissionId': 'permission-1'},
      };
      expect(
        shouldClearLegacyEarlyCheckoutDeduction(attendance, 'permission-1'),
        isTrue,
      );
      expect(
        shouldClearLegacyEarlyCheckoutDeduction(attendance, 'permission-2'),
        isFalse,
      );
    },
  );
}
