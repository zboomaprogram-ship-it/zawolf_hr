import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Allowlist of files legitimately permitted to use CircularProgressIndicator
/// or LinearProgressIndicator (per FR-L3: inline buttons and page-level blocking
/// actions with no layout to preserve).
const _allowedSpinnerFiles = <String>{
  'lib/design_system/components/buttons.dart',
  'lib/design_system/components/wolf_button.dart',
  'lib/design_system/components/stale_while_refresh.dart',
  'lib/screens/splash_screen.dart',
};

Iterable<File> _dartFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

String _normalized(File file) => file.path.replaceAll('\\', '/');

void main() {
  test('spinner allowlist guard (FR-L3): no raw spinners outside approved allowlist', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final path = _normalized(file);
      if (_allowedSpinnerFiles.contains(path)) continue;

      final content = file.readAsStringSync();
      if (content.contains('CircularProgressIndicator') ||
          content.contains('LinearProgressIndicator')) {
        violations.add(path);
      }
    }

    expect(
      violations.length,
      lessThanOrEqualTo(119),
      reason:
          'Spinner violations must not exceed baseline of 119 legacy files. Current: ${violations.length}.\n'
          '${violations.take(20).join('\n')}',
    );
  });
}
