import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files defining the design system primitives are permitted to define heights.
const _allowedSkeletonDefinitionFiles = <String>{
  'lib/design_system/components/skeletons.dart',
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
  test('skeleton height guard (FR-L3): no ad-hoc itemHeight in SkeletonList calls', () {
    final violations = <String>[];
    // Regex checking for explicit literal itemHeight assignments, e.g. itemHeight: 72, itemHeight: 88
    final adHocHeightRegex = RegExp(r'SkeletonList\s*\([^)]*itemHeight:\s*\d+');

    for (final file in _dartFiles('lib')) {
      final path = _normalized(file);
      if (_allowedSkeletonDefinitionFiles.contains(path)) continue;

      final content = file.readAsStringSync();
      if (adHocHeightRegex.hasMatch(content)) {
        violations.add(path);
      }
    }

    expect(
      violations.length,
      lessThanOrEqualTo(23),
      reason:
          'Skeleton height violations must not exceed baseline of 23 legacy files. Current: ${violations.length}.\n'
          '${violations.join('\n')}',
    );
  });
}
