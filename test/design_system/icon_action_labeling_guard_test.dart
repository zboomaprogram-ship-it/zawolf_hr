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
      violations,
      isEmpty,
      reason:
          'Found ${violations.length} files with IconButton missing tooltip or Semantics label. '
          'All icon buttons must have accessible tooltips per FR-A1:\n'
          '${violations.take(20).join('\n')}',
    );
  });
}
