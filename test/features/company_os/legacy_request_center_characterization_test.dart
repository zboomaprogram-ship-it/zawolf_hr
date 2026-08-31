import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/manager_approval_chain.dart';

void main() {
  test('existing request center keeps employee manager and HR routes', () {
    final source = File('lib/navigation/router.dart').readAsStringSync();
    expect(source, contains("path: '/employee/requests'"));
    expect(source, contains("path: '/manager/requests'"));
    expect(source, contains("path: '/hr/requests'"));
  });

  test('existing manager approval order deduplicates and preserves order', () {
    expect(
      ManagerApprovalChain.orderedIds(const [
        'manager-1',
        'manager-1',
        'manager-2',
      ], teamLeaderId: 'leader-1'),
      const ['leader-1', 'manager-1', 'manager-2'],
    );
  });

  test('existing employee request history still exposes approval stages', () {
    final source = File(
      'lib/components/employee_request_history_section.dart',
    ).readAsStringSync();
    expect(source, contains('pending_manager'));
    expect(source, contains('pending_hr'));
  });
}
