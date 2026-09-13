import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/dashboard_visual_analysis/domain/dashboard_visual_analysis.dart';

void main() {
  test('default seven-day period includes today and six preceding days', () {
    final period = DashboardPeriod.sevenDays(now: DateTime(2026, 9, 13, 16));
    expect(period.dayCount, 7);
    expect(period.start, DateTime(2026, 9, 7));
    expect(period.end, DateTime(2026, 9, 13));
  });

  test('custom periods reject more than 31 inclusive days', () {
    expect(() => DashboardPeriod.custom(DateTime(2026, 8, 1), DateTime(2026, 8, 31)), returnsNormally);
    expect(() => DashboardPeriod.custom(DateTime(2026, 8, 1), DateTime(2026, 9, 1)), throwsArgumentError);
  });
}
