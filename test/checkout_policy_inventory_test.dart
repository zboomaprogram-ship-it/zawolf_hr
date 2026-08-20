import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every known server checkout producer consults the shared policy', () {
    const requiredSources = <String, String>{
      'scripts/notification-web.js': 'loadCheckoutPolicy',
      'scripts/auto-attendance.js': 'loadCheckoutPolicy',
      'scripts/attendance-reminders.js': 'loadCheckoutPolicy',
      'scripts/dispatch-notifications.js': 'loadCheckoutPolicy',
      'scripts/daily-tasks.js': 'resolveCheckoutPolicyAt',
    };

    for (final entry in requiredSources.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains(entry.value), reason: entry.key);
    }
  });

  test('checkout policy has a safe default and an immutable event path', () {
    final source = File('scripts/checkout-policy.js').readAsStringSync();
    expect(source, contains("const POLICY_DOCUMENT = 'checkoutPolicy'"));
    expect(source, contains("const EVENTS_COLLECTION = 'events'"));
    expect(source, contains('enabled: asBoolean(data?.enabled)'));
    expect(source, contains('transaction.set(eventRef'));
  });
}
