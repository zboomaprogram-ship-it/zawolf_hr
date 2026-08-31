import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Route parity guard for specs/ui_redesign/02_navigation_ia_spec.md:
/// navigation redesign must never delete or rename an existing route.
/// Hubs may be added additively.
void main() {
  final routerSource = File('lib/navigation/router.dart').readAsStringSync();

  final RegExp pathPattern = RegExp(r"path:\s*'([^']+)'");
  final currentPaths = pathPattern
      .allMatches(routerSource)
      .map((match) => match.group(1)!)
      .toSet();

  test('router source parses at least one route', () {
    expect(currentPaths.length, greaterThan(20));
  });

  test('no duplicate route paths exist', () {
    final all = pathPattern
        .allMatches(routerSource)
        .map((match) => match.group(1)!)
        .toList();
    final duplicates = {
      ...all.where((path) => all.where((p) => p == path).length > 1),
    };
    expect(duplicates, isEmpty, reason: 'duplicate routes: $duplicates');
  });

  test('legacy routes survive the navigation redesign', () {
    const legacyManifest = <String>[
      // Shell + auth
      '/splash',
      '/login',
      '/privacy',
      '/terms',
      '/account-disabled',
      // Shared shell routes
      '/notifications',
      '/polls',
      '/workspace',
      // Employee
      '/employee/dashboard',
      '/employee/requests',
      '/employee/tasks',
      '/employee/performance',
      '/employee/kpi',
      '/employee/productivity',
      '/employee/profile',
      '/employee/suggestions',
      '/employee/warnings-rewards',
      '/employee/payroll',
      '/employee/deductions',
      '/assistant',
      // Team leader
      '/team-leader/dashboard',
      '/team-leader/attendance-summary',
      '/team-leader/employees',
      '/team-leader/tasks',
      '/team-leader/requests',
      // Manager
      '/manager/dashboard',
      '/manager/attendance-summary',
      '/manager/requests',
      '/manager/tasks',
      '/manager/team',
      '/manager/employees',
      '/manager/performance',
      '/manager/kpi',
      '/manager/productivity',
      '/manager/departments',
      '/manager/suggestions',
      '/manager/warnings-rewards',
      // HR
      '/hr/dashboard',
      '/hr/attendance-summary',
      '/hr/requests',
      '/hr/employees',
      '/hr/locations',
      '/hr/reports',
      '/hr/google-workspace',
      '/hr/payroll',
      '/hr/tasks',
      '/hr/kpi',
      '/hr/productivity',
      '/hr/departments',
      '/hr/warnings-rewards',
      '/hr/announcements',
      '/hr/day-offs',
      '/hr/attendance-policy',
      '/hr/field-assignments',
    ];

    final missing = legacyManifest.where((p) => !currentPaths.contains(p));
    expect(missing, isEmpty, reason: 'routes removed by redesign: $missing');
  });

  test('domain hubs are additive and present', () {
    for (final hub in [
      '/hub/time',
      '/hub/approvals',
      '/hub/payroll',
      '/hub/performance',
      '/hub/people',
    ]) {
      expect(currentPaths, contains(hub));
    }
  });

  test('security review tab is rendered only for HR/admin roles', () {
    final source = File(
      'lib/screens/manager/requests_mgmt.dart',
    ).readAsStringSync();
    expect(source, contains('final canReviewSecurity = EmployeeRole.isHr'));
    expect(
      source,
      contains("if (canReviewSecurity) const Tab(text: 'مراجعة أمنية')"),
    );
    expect(source, contains('if (canReviewSecurity) _buildSecurityReviewsTab'));
  });
}
