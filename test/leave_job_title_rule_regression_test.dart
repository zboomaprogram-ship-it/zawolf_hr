import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee leave fields permit the staffing job title snapshot', () {
    final rules = File('firestore.rules').readAsStringSync();
    final leaveSection = rules.substring(
      rules.indexOf('match /leaves/{leaveId}'),
      rules.indexOf('match /permissions/{permissionId}'),
    );
    expect(leaveSection, contains("'jobTitle'"));
  });
}
