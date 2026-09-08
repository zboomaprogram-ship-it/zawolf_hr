import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final priorityStrip =
      File(
        'lib/screens/employee/widgets/employee_priority_strip.dart',
      ).readAsStringSync();
  final historySection =
      File(
        'lib/components/employee_request_history_section.dart',
      ).readAsStringSync();
  final requestScreen =
      File('lib/screens/employee/employee_requests.dart').readAsStringSync();
  final router = File('lib/navigation/router.dart').readAsStringSync();

  test('pending dashboard shortcut opens filtered employee history', () {
    expect(priorityStrip, contains("'view': 'history'"));
    expect(priorityStrip, contains("'filter': 'pending'"));
    expect(priorityStrip, contains("'إجازة' => 'leave'"));
    expect(priorityStrip, contains("'إذن' => 'permission'"));
    expect(priorityStrip, contains("'طلب إداري' => 'administrative'"));
  });

  test('dashboard reuses history data to select the pending request type', () {
    expect(historySection, contains('onPendingCategory'));
    expect(historySection, contains('pending.first.type'));
  });

  test('history route selects its tab and pending-only filter', () {
    expect(
      router,
      contains("state.uri.queryParameters['filter'] == 'pending'"),
    );
    expect(router, contains("'administrative' => 5"));
    expect(requestScreen, contains('initialHistoryFilter'));
    expect(requestScreen, contains('initialHistoryTab'));
    expect(
      requestScreen,
      contains("key: ValueKey('history-\${widget.initialHistoryTab}')"),
    );
  });
}
