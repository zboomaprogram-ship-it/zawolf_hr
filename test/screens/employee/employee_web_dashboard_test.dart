import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zawolf_hr/models/employee_role.dart';
import 'package:zawolf_hr/models/user_model.dart';
import 'package:zawolf_hr/screens/employee/widgets/employee_web_dashboard_view.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  group('Employee Web Dashboard Architecture & Invariants', () {
    test('employee dashboard removes attendance check-in button on web', () {
      final source =
          File(
            'lib/screens/employee/employee_dashboard.dart',
          ).readAsStringSync();

      expect(source, contains('if (kIsWeb)'));
      expect(source, contains('تسجيل الحضور عبر تطبيق الجوال'));
      expect(
        source,
        contains('تسجيل الحضور والانصراف متاح حصراً عبر تطبيق الهاتف'),
      );
      expect(source, contains('EmployeeWebDashboardView'));
    });

    test('web navigation shell allows employee role with width >= 980', () {
      final wrapperSource =
          File('lib/navigation/navigation_wrapper.dart').readAsStringSync();

      expect(
        wrapperSource,
        contains('kIsWeb && MediaQuery.sizeOf(context).width >= 980;'),
      );

      final shellSource =
          File('lib/navigation/web_shell.dart').readAsStringSync();
      expect(shellSource, contains("'بوابة الموظف'"));
      expect(shellSource, contains('_sidebarCollapsed'));
      expect(shellSource, contains('WebChatNotificationOverlay'));
    });

    testWidgets(
      'EmployeeWebDashboardView renders header and mobile attendance notice',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final user = UserModel(
          uid: 'emp-123',
          email: 'employee@zawolf.ai',
          displayName: 'أحمد محمود',
          role: EmployeeRole.employee,
          employeeId: 'EMP-101',
          department: 'الهندسة البرمجية',
          position: 'مهندس برمجيات',
          organizationLevel: 'L2',
          organizationOrder: 1,
          locationId: 'loc-1',
          locationName: 'المقر الرئيسي',
          baseMonthlySalary: 12000,
          salaryCurrency: 'EGP',
          managerIds: const [],
          managerNames: const [],
          managerCodes: const [],
          isActive: true,
          workSchedule: WorkSchedule(),
          leaveBalance: LeaveBalance(
            annual: 18,
            sick: 10,
            casual: 4,
            daysOff: 12,
          ),
          permissionBalance: PermissionBalance(
            usedThisMonth: 1,
            usedHoursThisMonth: 2.0,
            lastResetMonth: '2026-09',
          ),
          notificationTokens: const [],
          unreadNotifications: 2,
          salesAnalyticsEnabled: false,
          salesAnalyticsRole: '',
          salesAnalyticsAgentKey: '',
          salesAnalyticsCompany: '',
          avatarGender: 'male',
          avatarAccent: 'cyan',
          preferredViewMode: 'grid',
          seenCelebrationBadgeIds: const [],
          excludeFromAttendanceReports: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmployeeWebDashboardView(
                user: user,
                logs: const [],
                todayLog: null,
                disciplineScore: 95.0,
                workedDays: 14,
                pendingRequestsCount: 2,
                onRefresh: () async {},
                taskStream: const Stream.empty(),
              ),
            ),
          ),
        );

        // Verify Welcome Header
        expect(find.text('مرحباً، أحمد محمود'), findsOneWidget);
        expect(find.text('تسجيل الحضور عبر تطبيق الجوال'), findsWidgets);

        // Verify Action Shortcuts
        expect(find.text('تقديم طلب جديد'), findsOneWidget);
        expect(find.text('قائمة مهامي'), findsOneWidget);
        expect(find.text('غرفة المحادثات'), findsOneWidget);

        // Verify Bento Grid KPIs
        expect(find.text('95%'), findsOneWidget);
        expect(find.text('نسبة الانضباط'), findsOneWidget);
        expect(find.text('18'), findsOneWidget);
        expect(find.text('رصيد الإجازات السنوية'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('طلبات معلقة'), findsOneWidget);
      },
    );
  });
}
