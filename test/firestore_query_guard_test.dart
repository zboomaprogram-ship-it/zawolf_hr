import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtime transformations do not launch additional Firestore reads', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final offenders = <String>[];
    final nestedRead = RegExp(
      r'\.snapshots\(\)[\s\S]{0,180}?\.asyncMap\([\s\S]{0,900}?\.get\(\)',
    );
    for (final file in files) {
      if (nestedRead.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A Firestore get() inside snapshots().asyncMap multiplies reads on every realtime emission.',
    );
  });

  test('high-volume request history stays bounded', () {
    final source = File(
      'lib/screens/employee/employee_requests.dart',
    ).readAsStringSync();
    expect(
      source,
      matches(
        RegExp(r"collection\('(leaves|permissions|advances|complaints)'\)"),
      ),
    );
    expect(
      RegExp(r'\.limit\(50\)\s*\.snapshots\(\)').allMatches(source),
      isEmpty,
      reason:
          'Employee history tabs must not restore the previous 50-row live feeds.',
    );
  });
}
