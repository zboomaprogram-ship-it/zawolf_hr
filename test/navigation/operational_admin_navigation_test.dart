import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/navigation/nav_config.dart';

void main() {
  const expectedPaths = <String>[
    '/hr/manual-attendance',
    '/hr/attendance-policy',
    '/hr/field-assignments',
    '/hr/meeting-rooms',
    '/meeting/approvals',
    '/meeting/history',
    '/hr/custom-request-types',
    '/hr/organization-trees',
    '/hr/custom-badges',
    '/company-os',
    '/workspace',
    '/hr/developer-tools',
    '/hr/diagnostics',
  ];

  for (final role in <String>[EmployeeRole.hrAdmin, EmployeeRole.superAdmin]) {
    test('operational administration features are visible to $role', () {
      final paths = navItemsForRole(role).map((item) => item.path).toSet();
      for (final path in expectedPaths) {
        expect(paths, contains(path));
      }
      expect(paths, isNot(contains('/hr/developer-api')));
    });
  }

  test('Developer API has no remaining application or runtime route', () {
    expect(
      File('lib/navigation/router.dart').readAsStringSync(),
      isNot(contains("path: '/hr/developer-api'")),
    );
    expect(
      File('scripts/notification-web.js').readAsStringSync(),
      isNot(contains("startsWith('/developer-api/v1/')")),
    );
  });

  test(
    'HR operational features are available from dashboard quick actions',
    () {
      final dashboard =
          File(
            'lib/screens/manager/widgets/unified_management_web_dashboard.dart',
          ).readAsStringSync();
      expect(dashboard, contains('..._buildHrOperationalShortcuts(context)'));
      for (final label in <String>[
        'تسجيل حضور يدوي',
        'سياسة الدوام',
        'المهام الميدانية / المأمورية',
        'قاعات الاجتماعات',
        'موافقات الاجتماعات',
        'سجل الاجتماعات',
        'أنواع الطلبات المخصصة',
        'الهيكل التنظيمي',
        'الشارات المخصصة',
        'مركز تشغيل الشركة',
        'مركز ملفات الشركة',
        'إدارة أدوات المطوّر',
      ]) {
        expect(dashboard, contains("label: '$label'"));
      }
    },
  );
}
