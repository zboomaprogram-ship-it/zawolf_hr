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
  test('silent catch guard: no unhandled/empty catch blocks in presentation layer', () {
    final violations = <String>[];
    // Matches catch (_) {} or catch (e) {} with empty body or only comments/whitespace
    final silentCatchRegex = RegExp(r'catch\s*\([^)]*\)\s*\{\s*(?:\/\/[^\n]*\s*)*\}');

    final scanDirs = ['lib/screens', 'lib/features'];
    for (final dir in scanDirs) {
      for (final file in _dartFiles(dir)) {
        final path = _normalized(file);
        // Only target presentation code
        if (!path.contains('/presentation/') && !path.startsWith('lib/screens/')) {
          continue;
        }

        final content = file.readAsStringSync();
        if (silentCatchRegex.hasMatch(content)) {
          violations.add(path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found ${violations.length} presentation files with silent catch blocks. '
          'Errors must be surfaced via state, banner, or SnackBar per FR-S2:\n'
          '${violations.take(20).join('\n')}',
    );
  });
}
