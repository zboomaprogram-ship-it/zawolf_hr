import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Company OS rollout does not remove legacy operational routes', () {
    final source = File('lib/navigation/router.dart').readAsStringSync();
    for (final route in <String>[
      '/employee/requests',
      '/employee/payroll',
      '/employee/tasks',
      '/manager/requests',
      '/manager/tasks',
      '/hr/requests',
      '/hr/payroll',
      '/workspace',
    ]) {
      expect(source, contains("path: '$route'"), reason: 'missing $route');
    }
  });
}
