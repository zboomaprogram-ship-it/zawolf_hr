import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  test('Arabic-only closed-i18n guard: no multi-language or localization framework packages', () {
    final forbiddenPackages = [
      'package:easy_localization',
      'package:flutter_gen/gen_l10n',
      'package:intl_translation',
    ];

    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final path = _normalized(file);
      final content = file.readAsStringSync();
      for (final forbidden in forbiddenPackages) {
        if (content.contains(forbidden)) {
          violations.add('$path ($forbidden)');
        }
      }

      // flutter_localizations is only permitted in lib/main.dart for GlobalMaterialLocalizations
      if (path != 'lib/main.dart' && content.contains('package:flutter_localizations')) {
        violations.add('$path (package:flutter_localizations)');
      }
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pubspecViolations = <String>[];
    for (final pkg in ['easy_localization', 'intl_translation']) {
      if (pubspec.contains('$pkg:')) {
        pubspecViolations.add(pkg);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'ZaWolf HR is strictly Arabic-only (closed i18n). '
          'No localization framework imports are permitted:\n'
          '${violations.join('\n')}',
    );

    expect(
      pubspecViolations,
      isEmpty,
      reason:
          'Found forbidden localization packages in pubspec.yaml: ${pubspecViolations.join(', ')}',
    );
  });
}
