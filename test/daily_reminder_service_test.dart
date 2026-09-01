import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/daily_reminder_service.dart';

void main() {
  test('legacy attendance reminder ranges do not overlap', () {
    final morningIds = {
      for (var day = 0; day < kReminderScheduleDays; day++)
        kMorningCheckInReminderId + day,
    };
    final checkoutIds = {
      for (var day = 0; day < kReminderScheduleDays; day++)
        kCheckOutReminderId + day,
    };

    expect(morningIds.intersection(checkoutIds), isEmpty);
  });
}
