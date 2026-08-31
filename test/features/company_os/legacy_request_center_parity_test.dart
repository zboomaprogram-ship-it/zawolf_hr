import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Company OS keeps the canonical administrative request aggregate', () {
    final server = File('scripts/company-os/requests.js').readAsStringSync();
    expect(server, contains("REQUEST_COLLECTION = 'administrativeRequests'"));
    expect(server, contains('collection(REQUEST_COLLECTION)'));
    expect(server, isNot(contains("collection('companyOsRequests')")));
    expect(server, contains('approvalHistory'));
  });

  test(
    'employee and management screens retain the shared approval journey',
    () {
      final employee = File(
        'lib/screens/employee/employee_requests.dart',
      ).readAsStringSync();
      final manager = File(
        'lib/screens/manager/requests_mgmt.dart',
      ).readAsStringSync();
      expect(employee, contains('RequestApprovalTimeline'));
      expect(manager, contains('RequestApprovalTimeline'));
    },
  );

  test('request notifications deep-link to the canonical request center', () {
    final server = File(
      'scripts/company-os/notifications.js',
    ).readAsStringSync();
    expect(server, contains('/requests/operational/'));
    expect(server, contains('requestId'));
  });
}
