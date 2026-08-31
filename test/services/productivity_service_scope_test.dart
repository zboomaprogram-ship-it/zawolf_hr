import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supervisor KPI aggregation is role-scoped, never a broad month scan', () {
    final source = File(
      'lib/services/productivity_service.dart',
    ).readAsStringSync();

    expect(source, contains('_loadSupervisedKpiScores'));
    expect(
      source,
      contains("base.where('managerIds', arrayContains: user.uid)"),
    );
    expect(source, contains("base.where('teamLeaderId', isEqualTo: user.uid)"));
    expect(
      source,
      isNot(
        contains(
          ".collection('employeeKpis')\n          .where('monthKey', isEqualTo: monthKey)\n          .get()",
        ),
      ),
    );
  });
}
