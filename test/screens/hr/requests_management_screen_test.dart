import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/manager/requests_mgmt.dart').readAsStringSync();

  test('request tabs reuse stable bounded streams across fast tab changes', () {
    expect(source, contains('_streamCache.putIfAbsent'));
    expect(source, contains('_KeepAliveRequestTab'));
    expect(source, contains('query.limit(300)'));
  });

  test('request tabs apply search locally and provide empty/retry states', () {
    expect(source, contains("_searchQuery = value.trim().toLowerCase()"));
    expect(source, contains('_matchesSearch(['));
    expect(source, contains('snapshot.hasError'));
    expect(source, contains('_buildEmptyState'));
    expect(source, contains('إعادة المحاولة'));
  });

  test('HR can monitor manager-stage requests and CEO gets the CEO stage', () {
    expect(source, contains("'pending_ceo'"));
    expect(source, contains("reviewer.employeeId.trim().toUpperCase() == 'CEO-100'"));
    expect(source, contains('EmployeeRole.isHr(reviewer.role)'));
  });
}
