import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/utils/payroll_cycle.dart';

void main() {
  group('PayrollCycle', () {
    test('uses the current month through day 25', () {
      final cycle = PayrollCycle.forDate(DateTime(2026, 7, 25));

      expect(cycle.key, '2026-07');
      expect(cycle.startDateKey, '2026-06-26');
      expect(cycle.endDateKey, '2026-07-25');
      expect(cycle.nextStartDateKey, '2026-07-26');
    });

    test('opens the next cycle on day 26', () {
      final cycle = PayrollCycle.forDate(DateTime(2026, 7, 26));

      expect(cycle.key, '2026-08');
      expect(cycle.startDateKey, '2026-07-26');
      expect(cycle.endDateKey, '2026-08-25');
    });

    test('handles the year boundary', () {
      final cycle = PayrollCycle.forDate(DateTime(2026, 12, 26));

      expect(cycle.key, '2027-01');
      expect(cycle.startDateKey, '2026-12-26');
      expect(cycle.endDateKey, '2027-01-25');
    });
  });
}
