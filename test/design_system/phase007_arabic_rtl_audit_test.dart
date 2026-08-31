import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 007 presentation never exposes provider error vocabulary', () {
    for (final feature in <String>[
      'employee_operations',
      'operational_visibility',
      'request_visibility',
      'sales_indicators',
      'diagnostics',
      'assistant',
      'conversations',
    ]) {
      final root = Directory('lib/features/$feature/presentation');
      if (!root.existsSync()) continue;
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync().toLowerCase();
        for (final forbidden in <String>[
          'cloud_firestore/',
          'firebaseexception',
          'permission-denied',
          'stacktrace',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: file.path);
        }
      }
    }
  });

  test('web shell preserves browser selection and Ctrl+F text discovery', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('SelectionArea'));
    expect(source, contains('kIsWeb'));
  });

  test('new Arabic operational pages declare RTL surfaces', () {
    for (final path in <String>[
      'lib/features/diagnostics/presentation/pages/diagnostics_report_page.dart',
      'lib/features/sales_indicators/presentation/pages/sales_indicators_panel.dart',
      'lib/features/operational_visibility/presentation/pages/employee_operations_timeline_page.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('TextDirection.rtl'),
        reason: path,
      );
    }
  });
}
