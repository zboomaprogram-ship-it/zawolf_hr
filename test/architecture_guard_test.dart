import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _legacyUiInfrastructureAllowlist = <String>{
  'lib/components/attendance_heatmap_card.dart',
  'lib/components/employee_request_history_section.dart',
  'lib/components/request_approval_timeline.dart',
  'lib/screens/employee/employee_dashboard.dart',
  'lib/screens/employee/employee_requests.dart',
  'lib/screens/hr/announcements.dart',
  'lib/screens/hr/attendance_policy_settings_screen.dart',
  'lib/screens/hr/department_performance_screen.dart',
  'lib/screens/hr/employee_mgmt.dart',
  'lib/screens/hr/field_assignments_screen.dart',
  'lib/screens/hr/hr_dashboard.dart',
  'lib/screens/hr/location_mgmt.dart',
  'lib/screens/manager/manager_dashboard.dart',
  'lib/screens/manager/requests_mgmt.dart',
  'lib/screens/manager/team_attendance.dart',
  'lib/screens/manager/team_members_screen.dart',
  'lib/screens/shared/employee_insights_screen.dart',
  'lib/screens/shared/notifications_screen.dart',
  'lib/screens/shared/polls_screen.dart',
};

Iterable<File> _dartFiles(String root) {
  final directory = Directory(root);
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

String _repoPath(File file) => file.path.replaceAll('\\', '/');

void main() {
  test('migrated presentation does not depend on data or infrastructure', () {
    final violations = <String>[];
    final forbidden = <RegExp>[
      RegExp(r'''^\s*import\s+['"][^'"]*/data/''', multiLine: true),
      RegExp(r'''^\s*import\s+['"]package:cloud_firestore/''', multiLine: true),
      RegExp(r'''^\s*import\s+['"]package:firebase_[^'"]*''', multiLine: true),
      RegExp(r'''^\s*import\s+['"]package:dio/''', multiLine: true),
      RegExp(r'''^\s*import\s+['"][^'"]*/services/''', multiLine: true),
      RegExp(r'''^\s*import\s+['"]package:(?:http|drift)/''', multiLine: true),
    ];

    for (final file in _dartFiles('lib/features')) {
      final path = _repoPath(file);
      if (!path.contains('/presentation/')) continue;
      final source = file.readAsStringSync();
      if (forbidden.any((pattern) => pattern.hasMatch(source))) {
        violations.add(path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Presentation must depend on domain contracts, not data/Firebase/Dio.',
    );
  });

  test('core error contracts stay provider and presentation independent', () {
    final forbidden = <RegExp>[
      RegExp(r'''^\s*import\s+['"]package:cloud_firestore/''', multiLine: true),
      RegExp(r'''^\s*import\s+['"]package:firebase_''', multiLine: true),
      RegExp(
        r'''^\s*import\s+['"]package:(?:http|dio|provider|flutter)/''',
        multiLine: true,
      ),
      RegExp(r'''^\s*import\s+['"][^'"]*(?:storage|bloc)''', multiLine: true),
    ];
    final violations = <String>[];

    for (final file in _dartFiles('lib/core/errors')) {
      if (forbidden.any(
        (pattern) => pattern.hasMatch(file.readAsStringSync()),
      )) {
        violations.add(_repoPath(file));
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Core error contracts must remain pure and provider/presentation independent.',
    );
  });

  test('legacy user-facing error utility is not coupled to the new core', () {
    final source = File('lib/utils/user_facing_error.dart').readAsStringSync();

    expect(source, isNot(contains('core/errors')));
    expect(source, isNot(contains('OperationResult')));
    expect(source, isNot(contains('AppFailure')));
  });

  test('legacy UI direct-infrastructure allowlist does not grow', () {
    final directInfrastructure = RegExp(
      r"package:(?:cloud_firestore|firebase_[^/]+|dio)/|"
      r'FirebaseFirestore\b|FirebaseAuth\b|\bDio\s*\(',
    );
    final offenders = <String>{};

    for (final root in const ['lib/screens', 'lib/components']) {
      for (final file in _dartFiles(root)) {
        if (directInfrastructure.hasMatch(file.readAsStringSync())) {
          offenders.add(_repoPath(file));
        }
      }
    }

    final newViolations = offenders.difference(
      _legacyUiInfrastructureAllowlist,
    );
    expect(
      newViolations,
      isEmpty,
      reason:
          'Do not add Firebase/Dio access to UI. Put it behind a repository contract.',
    );
  });

  test('new Cubits stay focused and below the manual-review threshold', () {
    final oversized = <String>[];
    for (final file in _dartFiles('lib/features')) {
      final path = _repoPath(file);
      if (!path.endsWith('_cubit.dart') || path.endsWith('.g.dart')) continue;
      final lineCount = file.readAsLinesSync().length;
      if (lineCount > 300) oversized.add('$path ($lineCount lines)');
    }

    expect(
      oversized,
      isEmpty,
      reason: 'Cubits over 300 lines require a responsibility split or review.',
    );
  });

  test(
    'Company Workspace V2 preserves the domain/data/presentation boundary',
    () {
      final domainViolations = <String>[];
      final dataViolations = <String>[];
      for (final file in _dartFiles('lib/features/company_workspace/domain')) {
        final source = file.readAsStringSync();
        if (RegExp(
          r'''package:(?:flutter|firebase_|cloud_firestore|http|drift)/''',
        ).hasMatch(source)) {
          domainViolations.add(_repoPath(file));
        }
      }
      for (final file in _dartFiles('lib/features/company_workspace/data')) {
        final source = file.readAsStringSync();
        if (RegExp(r'''/presentation/''').hasMatch(source)) {
          dataViolations.add(_repoPath(file));
        }
      }

      expect(domainViolations, isEmpty);
      expect(dataViolations, isEmpty);
    },
  );

  test('Company OS preserves domain/data/presentation boundaries', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib/features/company_os/domain')) {
      final source = file.readAsStringSync();
      if (RegExp(
        r'''package:(?:flutter|firebase_|cloud_firestore|http|drift)/''',
      ).hasMatch(source)) {
        violations.add(_repoPath(file));
      }
    }
    for (final file in _dartFiles('lib/features/company_os/data')) {
      if (file.readAsStringSync().contains('/presentation/')) {
        violations.add(_repoPath(file));
      }
    }
    expect(violations, isEmpty);
  });

  test(
    'Organization structure preserves domain/data/presentation boundaries',
    () {
      final violations = <String>[];
      for (final file in _dartFiles(
        'lib/features/organization_structure/domain',
      )) {
        final source = file.readAsStringSync();
        if (RegExp(
          r'''package:(?:flutter|firebase_|cloud_firestore|http|drift)/''',
        ).hasMatch(source)) {
          violations.add(_repoPath(file));
        }
      }
      for (final file in _dartFiles(
        'lib/features/organization_structure/data',
      )) {
        if (file.readAsStringSync().contains('/presentation/')) {
          violations.add(_repoPath(file));
        }
      }
      expect(violations, isEmpty);
    },
  );

  test(
    'Company OS Cubits remain focused and presentation stays infrastructure free',
    () {
      final violations = <String>[];
      for (final file in _dartFiles('lib/features/company_os/presentation')) {
        final source = file.readAsStringSync();
        if (source.contains('FirebaseFirestore') ||
            source.contains('cloud_firestore') ||
            source.contains('/data/')) {
          violations.add(_repoPath(file));
        }
        if (file.path.endsWith('_cubit.dart') &&
            file.readAsLinesSync().length > 300) {
          violations.add('${_repoPath(file)} exceeds 300 lines');
        }
      }
      expect(violations, isEmpty);
    },
  );

  test('every migrated feature has a specification directory', () {
    final featuresRoot = Directory('lib/features');
    if (!featuresRoot.existsSync()) return;

    final missingSpecs = <String>[];
    for (final entry in featuresRoot.listSync(followLinks: false)) {
      if (entry is! Directory || _dartFiles(entry.path).isEmpty) continue;
      final featureName = entry.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      final specDirectory = Directory('specs/$featureName');
      final hasMarkdown =
          specDirectory.existsSync() &&
          specDirectory
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .any((file) => file.path.endsWith('.md'));
      if (!hasMarkdown) missingSpecs.add(featureName);
    }

    expect(
      missingSpecs,
      isEmpty,
      reason: 'Each lib/features/<feature> requires specs/<feature>/*.md.',
    );
  });
}
