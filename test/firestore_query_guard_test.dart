import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'request visibility keeps Firestore access behind its bounded data seam',
    () {
      final source = File(
        'lib/features/request_visibility/data/request_visibility_repository.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, contains('loadBounded(RequestViewQuery query)'));
      final querySource = File(
        'lib/features/request_visibility/domain/entities/request_view_query.dart',
      ).readAsStringSync();
      expect(querySource, contains('pageSize > 0 && pageSize <= 100'));
    },
  );

  test(
    'request visibility Firestore adapter applies a page limit and manager scope',
    () {
      final source = File(
        'lib/features/request_visibility/data/firestore_request_visibility_data_source.dart',
      ).readAsStringSync();

      expect(source, contains(".where('managerId',"));
      expect(source, contains("'managerIds'"));
      expect(source, contains('arrayContains: query.actorScope.actorId'));
      expect(source, contains("'manual_deductions'"));
      expect(source, contains('request.limit(limit).get()'));
      expect(source, isNot(contains('.snapshots()')));
      expect(source, contains("'hr_admin'"));
      expect(source, contains("'hr'"));
    },
  );

  test('snapshot transforms do not trigger a second month-wide get query', () {
    for (final path in <String>[
      'lib/services/kpi_service.dart',
      'lib/services/productivity_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final transformWithGet = RegExp(
        r'snapshots\(\)[\s\S]{0,700}asyncMap[\s\S]{0,700}\.get\(',
      );
      expect(transformWithGet.hasMatch(source), isFalse, reason: path);
    }
  });

  test('Company Workspace V2 does not query Firestore from presentation', () {
    final root = Directory('lib/features/company_workspace/presentation');
    if (!root.existsSync()) return;
    final offenders = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains('FirebaseFirestore') ||
              source.contains('cloud_firestore') ||
              source.contains('.snapshots()');
        })
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('Phase 007 presentation never opens Firestore listeners directly', () {
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
        final source = file.readAsStringSync();
        expect(source, isNot(contains('cloud_firestore')), reason: file.path);
        expect(source, isNot(contains('FirebaseFirestore')), reason: file.path);
        expect(source, isNot(contains('.snapshots()')), reason: file.path);
      }
    }
  });

  test('new server report and sales registry reads remain bounded', () {
    final server = File('scripts/notification-web.js').readAsStringSync();
    final sales = File('scripts/sync-sales-kpis.js').readAsStringSync();
    expect(server, contains("collection('diagnosticAggregates')"));
    expect(server, contains(".limit(250)"));
    expect(sales, contains("collection('salesIdentityMappings')"));
    expect(sales, contains('.limit(500)'));
  });

  test('Company OS server operations never use an unbounded get', () {
    for (final path in <String>[
      'scripts/company-os/dashboard.js',
      'scripts/company-os/operations.js',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('limit('), reason: path);
      expect(
        RegExp(r'collection\([^)]*\)\.get\(\)').hasMatch(source),
        isFalse,
        reason: path,
      );
      expect(
        RegExp(r'where\([^)]*\)\.get\(\)').hasMatch(source),
        isFalse,
        reason: path,
      );
    }
  });

  test(
    'organization server reads are bounded and presentation has no listeners',
    () {
      for (final path in <String>[
        'scripts/company-os/router.js',
        'scripts/company-os/organization-firestore-store.js',
        'scripts/company-os/migrate-organization-structure.js',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('limit('), reason: path);
        expect(
          RegExp(r'collection\([^)]*\)\.get\(\)').hasMatch(source),
          isFalse,
          reason: path,
        );
      }
      for (final file in Directory(
        'lib/features/organization_structure/presentation',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        expect(source, isNot(contains('cloud_firestore')), reason: file.path);
        expect(source, isNot(contains('.snapshots()')), reason: file.path);
      }
    },
  );
}
