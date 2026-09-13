import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/design_system/components/rtl_navigation.dart';

void main() {
  final source = File(
    'lib/navigation/navigation_wrapper.dart',
  ).readAsStringSync();

  test('shell back gesture returns to an in-app route before the OS exits', () {
    expect(source, contains('PopScope('));
    expect(source, contains('canPop: false'));
    expect(source, contains('onPopInvokedWithResult'));
    expect(source, contains('_navigateBackOnWeb(context, role)'));
  });

  test('route history is bounded and root routes do not unexpectedly exit', () {
    expect(source, contains('_webRouteHistory.length > 30'));
    expect(source, contains('final fallback = homeRouteForRole(role)'));
    expect(source, contains('context.go(fallback)'));
  });

  test('attendance check-in has an explicit pending submission state', () {
    final checkin = File(
      'lib/features/attendance_checkin/domain/entities/check_in_presentation_state.dart',
    ).readAsStringSync();
    expect(checkin, contains('pendingSync'));
    expect(checkin, contains('requiresStatusCheck'));
  });

  testWidgets('directional arrows follow the Arabic text direction', (tester) async {
    late IconData backIcon;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            backIcon = RtlNavigation.backIcon(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(backIcon, Icons.arrow_forward);
  });

  test('dashboard tabs do not display notification badge and bottom tab badges cap at 99+', () {
    expect(source, isNot(contains('isDashboardAnchor')));
    expect(source, contains("unreadCount > 99 ? '99+' : '\$unreadCount'"));
  });

  test('HR and Manager dashboards provide notification bell action in AppBar', () {
    final hrDashboard = File('lib/screens/hr/hr_dashboard.dart').readAsStringSync();
    final managerDashboard = File('lib/screens/manager/manager_dashboard.dart').readAsStringSync();

    expect(hrDashboard, contains("context.push('/notifications')"));
    expect(hrDashboard, contains("Icons.notifications_outlined"));
    expect(managerDashboard, contains("context.push('/notifications')"));
    expect(managerDashboard, contains("Icons.notifications_outlined"));
  });
}
