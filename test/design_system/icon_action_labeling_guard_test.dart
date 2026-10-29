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
  test('icon action labeling guard (FR-A1): IconButton must have tooltip or semantics label', () {
    final violations = <String>[];
    // Simple heuristic: matches IconButton( where neither tooltip nor semanticsLabel is supplied
    final iconButtonBlockRegex = RegExp(r'IconButton\s*\(([^;]*?)\)', dotAll: true);

    for (final file in _dartFiles('lib')) {
      final path = _normalized(file);
      final content = file.readAsStringSync();

      for (final match in iconButtonBlockRegex.allMatches(content)) {
        final block = match.group(1) ?? '';
        if (!block.contains('tooltip:') && !block.contains('semanticsLabel:')) {
          violations.add(path);
          break;
        }
      }
    }

    expect(
      violations.length,
      lessThanOrEqualTo(44),
      reason:
          'Unlabeled icon buttons must not exceed baseline of 44 legacy files. Current: ${violations.length}.\n'
          '${violations.take(20).join('\n')}',
    );
  });
}
