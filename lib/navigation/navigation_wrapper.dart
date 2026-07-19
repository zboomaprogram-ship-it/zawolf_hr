import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../models/employee_role.dart';
import '../theme/theme.dart';

import 'package:badges/badges.dart' as badges;
import '../services/notification_service.dart';
import '../services/pending_requests_service.dart';
import '../services/required_attendance_alarm_service.dart';
import '../models/user_model.dart';
import 'dart:async';

class NavigationWrapper extends StatefulWidget {
  final Widget child;

  const NavigationWrapper({super.key, required this.child});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notifTapSub;
  String? _currentUserUid;
  String? _attendanceAlarmCheckedForUid;
  UserModel? _alarmUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifTapSub = NotificationService.instance.onNotificationTap.listen((
      route,
    ) {
      if (mounted && route.isNotEmpty) {
        context.go(route);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifTapSub?.cancel();
    PendingRequestsService.instance.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _alarmUser == null) return;
    unawaited(
      RequiredAttendanceAlarmService.instance
          .syncIfEnabled(_alarmUser!)
          .catchError((_) => false),
    );
  }

  void _checkRequiredAttendanceAlarm(UserModel user) {
    if (kIsWeb) return;
    if (_attendanceAlarmCheckedForUid == user.uid) return;
    _attendanceAlarmCheckedForUid = user.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final alreadyEnabled = await RequiredAttendanceAlarmService.instance
            .syncIfEnabled(user);
        if (alreadyEnabled || !mounted) return;
        final alreadyPrompted = await RequiredAttendanceAlarmService.instance
            .hasPrompted(user.uid);
        if (alreadyPrompted || !mounted) return;

        final startTime = RequiredAttendanceAlarmService.instance.startTimeFor(
          user,
        );
        final shouldEnable = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('منبه تسجيل الحضور'),
            content: Text(
              'يمكنك تفعيل منبه اختياري للحضور الساعة $startTime. يعمل بصوت الذئب في أيام العمل، ويتوقف تلقائياً في الإجازات المعتمدة وأيام العطلة. يمكنك متابعة استخدام التطبيق من دون تفعيله.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ليس الآن'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.alarm),
                label: const Text('تفعيل'),
              ),
            ],
          ),
        );
        await RequiredAttendanceAlarmService.instance.markPrompted(user.uid);
        if (shouldEnable != true || !mounted) return;

        final settings = await RequiredAttendanceAlarmService.instance
            .enableFor(user);
        RequiredAttendanceAlarmService.instance.startWatching(user);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تفعيل منبه الحضور الساعة ${settings.formattedTime}.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    _alarmUser = user;
    final theme = Theme.of(context);

    if (user == null) {
      if (_currentUserUid != null) {
        _currentUserUid = null;
        _attendanceAlarmCheckedForUid = null;
        PendingRequestsService.instance.stopListening();
      }
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    if (_currentUserUid != user.uid) {
      _currentUserUid = user.uid;
      if (user.role == EmployeeRole.manager ||
          user.role == EmployeeRole.hrAdmin ||
          user.role == EmployeeRole.superAdmin) {
        PendingRequestsService.instance.startListening(user);
      } else {
        PendingRequestsService.instance.stopListening();
      }
    }
    _checkRequiredAttendanceAlarm(user);

    final String matchedLocation = GoRouterState.of(context).matchedLocation;
    final String role = user.role;

    // Define tabs based on role
    List<NavigationItem> items = [];
    if (role == EmployeeRole.employee) {
      items = [
        NavigationItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'الرئيسية',
          englishLabel: 'Home',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.task_alt_outlined,
          activeIcon: Icons.task_alt,
          label: 'مهامي',
          englishLabel: 'Tasks',
          path: '/employee/tasks',
        ),
        NavigationItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: 'أدائي',
          englishLabel: 'Performance',
          path: '/employee/performance',
        ),
        NavigationItem(
          icon: Icons.flag_outlined,
          activeIcon: Icons.flag,
          label: 'KPI',
          englishLabel: 'Goals',
          path: '/employee/kpi',
        ),
        NavigationItem(
          icon: Icons.insights_outlined,
          activeIcon: Icons.insights,
          label: 'إنتاجيتي',
          englishLabel: 'Productivity',
          path: '/employee/productivity',
        ),
        NavigationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'حسابي',
          englishLabel: 'Profile',
          path: '/employee/profile',
        ),
        NavigationItem(
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium,
          label: 'السجل',
          englishLabel: 'Records',
          path: '/employee/warnings-rewards',
        ),
        NavigationItem(
          icon: Icons.payments_outlined,
          activeIcon: Icons.payments,
          label: 'راتبي',
          englishLabel: 'Payroll',
          path: '/employee/payroll',
        ),
        NavigationItem(
          icon: Icons.lightbulb_outline,
          activeIcon: Icons.lightbulb,
          label: 'مقترحاتي',
          englishLabel: 'Suggestions',
          path: '/employee/suggestions',
        ),
      ];
    } else if (role == EmployeeRole.teamLeader) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.groups_2_outlined,
          activeIcon: Icons.groups_2,
          label: 'فريقي',
          englishLabel: 'My Team',
          path: '/team-leader/dashboard',
        ),
        NavigationItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: 'الأعضاء',
          englishLabel: 'Members',
          path: '/team-leader/employees',
        ),
        NavigationItem(
          icon: Icons.task_alt_outlined,
          activeIcon: Icons.task_alt,
          label: 'مهام الفريق',
          englishLabel: 'Team Tasks',
          path: '/team-leader/tasks',
        ),
        NavigationItem(
          icon: Icons.check_circle_outline,
          activeIcon: Icons.check_circle,
          label: 'مهامي',
          englishLabel: 'My Tasks',
          path: '/employee/tasks',
        ),
        NavigationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'حسابي',
          englishLabel: 'Profile',
          path: '/employee/profile',
        ),
      ];
    } else if (role == EmployeeRole.manager) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.dashboard_customize_outlined,
          activeIcon: Icons.dashboard_customize,
          label: 'لوحتي',
          englishLabel: 'Dashboard',
          path: '/manager/dashboard',
        ),
        NavigationItem(
          icon: Icons.rule_outlined,
          activeIcon: Icons.rule,
          label: 'الطلبات',
          englishLabel: 'Approvals',
          path: '/manager/requests',
        ),
        NavigationItem(
          icon: Icons.task_alt_outlined,
          activeIcon: Icons.task_alt,
          label: 'المهام',
          englishLabel: 'Tasks',
          path: '/manager/tasks',
        ),
        NavigationItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: 'فريقي',
          englishLabel: 'Team Attendance',
          path: '/manager/team',
        ),
        NavigationItem(
          icon: Icons.grade_outlined,
          activeIcon: Icons.grade,
          label: 'الأداء',
          englishLabel: 'Team Performance',
          path: '/manager/performance',
        ),
        NavigationItem(
          icon: Icons.flag_outlined,
          activeIcon: Icons.flag,
          label: 'KPI',
          englishLabel: 'Goals',
          path: '/manager/kpi',
        ),
        NavigationItem(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard,
          label: 'الإنتاجية',
          englishLabel: 'Ranking',
          path: '/manager/productivity',
        ),
        NavigationItem(
          icon: Icons.domain_outlined,
          activeIcon: Icons.domain,
          label: 'الأقسام',
          englishLabel: 'Departments',
          path: '/manager/departments',
        ),
        NavigationItem(
          icon: Icons.lightbulb_outline,
          activeIcon: Icons.lightbulb,
          label: 'المقترحات',
          englishLabel: 'Suggestions',
          path: '/manager/suggestions',
        ),
        NavigationItem(
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium,
          label: 'السجلات',
          englishLabel: 'Records',
          path: '/manager/warnings-rewards',
        ),
        NavigationItem(
          icon: Icons.support_agent_outlined,
          activeIcon: Icons.support_agent,
          label: 'المساعد',
          englishLabel: 'Assistant',
          path: '/assistant',
        ),
        NavigationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'حسابي',
          englishLabel: 'Profile',
          path: '/employee/profile',
        ),
      ];
    } else if (role == EmployeeRole.hrAdmin) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'لوحة التحكم',
          englishLabel: 'Control Panel',
          path: '/hr/dashboard',
        ),
        NavigationItem(
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge,
          label: 'الموظفون',
          englishLabel: 'Employees',
          path: '/hr/employees',
        ),
        NavigationItem(
          icon: Icons.add_location_alt_outlined,
          activeIcon: Icons.add_location_alt,
          label: 'المواقع',
          englishLabel: 'Locations',
          path: '/hr/locations',
        ),
        NavigationItem(
          icon: Icons.assessment_outlined,
          activeIcon: Icons.assessment,
          label: 'التقارير',
          englishLabel: 'Reports',
          path: '/hr/reports',
        ),
        NavigationItem(
          icon: Icons.payments_outlined,
          activeIcon: Icons.payments,
          label: 'الرواتب',
          englishLabel: 'Payroll',
          path: '/hr/payroll',
        ),
        NavigationItem(
          icon: Icons.task_alt_outlined,
          activeIcon: Icons.task_alt,
          label: 'المهام',
          englishLabel: 'Tasks',
          path: '/hr/tasks',
        ),
        NavigationItem(
          icon: Icons.flag_outlined,
          activeIcon: Icons.flag,
          label: 'KPI',
          englishLabel: 'Goals',
          path: '/hr/kpi',
        ),
        NavigationItem(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard,
          label: 'الإنتاجية',
          englishLabel: 'Ranking',
          path: '/hr/productivity',
        ),
        NavigationItem(
          icon: Icons.domain_outlined,
          activeIcon: Icons.domain,
          label: 'الأقسام',
          englishLabel: 'Departments',
          path: '/hr/departments',
        ),
        NavigationItem(
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium,
          label: 'السجلات',
          englishLabel: 'Records',
          path: '/hr/warnings-rewards',
        ),
        NavigationItem(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign,
          label: 'الإعلانات',
          englishLabel: 'Announcements',
          path: '/hr/announcements',
        ),
        NavigationItem(
          icon: Icons.event_busy_outlined,
          activeIcon: Icons.event_busy,
          label: 'أيام العطلة',
          englishLabel: 'Days Off',
          path: '/hr/day-offs',
        ),
        NavigationItem(
          icon: Icons.support_agent_outlined,
          activeIcon: Icons.support_agent,
          label: 'المساعد',
          englishLabel: 'Assistant',
          path: '/assistant',
        ),
        NavigationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'حسابي',
          englishLabel: 'Profile',
          path: '/employee/profile',
        ),
      ];
    } else if (role == EmployeeRole.superAdmin) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'تحكم',
          englishLabel: 'Control',
          path: '/hr/dashboard',
        ),
        NavigationItem(
          icon: Icons.rule_outlined,
          activeIcon: Icons.rule,
          label: 'الموافقات',
          englishLabel: 'Approvals',
          path: '/manager/requests',
        ),
        NavigationItem(
          icon: Icons.task_alt_outlined,
          activeIcon: Icons.task_alt,
          label: 'المهام',
          englishLabel: 'Tasks',
          path: '/manager/tasks',
        ),
        NavigationItem(
          icon: Icons.flag_outlined,
          activeIcon: Icons.flag,
          label: 'KPI',
          englishLabel: 'Goals',
          path: '/manager/kpi',
        ),
        NavigationItem(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard,
          label: 'الإنتاجية',
          englishLabel: 'Ranking',
          path: '/manager/productivity',
        ),
        NavigationItem(
          icon: Icons.domain_outlined,
          activeIcon: Icons.domain,
          label: 'الأقسام',
          englishLabel: 'Departments',
          path: '/hr/departments',
        ),
        NavigationItem(
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge,
          label: 'الموظفون',
          englishLabel: 'Employees',
          path: '/hr/employees',
        ),
        NavigationItem(
          icon: Icons.payments_outlined,
          activeIcon: Icons.payments,
          label: 'الرواتب',
          englishLabel: 'Payroll',
          path: '/hr/payroll',
        ),
        NavigationItem(
          icon: Icons.add_location_alt_outlined,
          activeIcon: Icons.add_location_alt,
          label: 'المواقع',
          englishLabel: 'Locations',
          path: '/hr/locations',
        ),
        NavigationItem(
          icon: Icons.event_busy_outlined,
          activeIcon: Icons.event_busy,
          label: 'أيام العطلة',
          englishLabel: 'Days Off',
          path: '/hr/day-offs',
        ),
        NavigationItem(
          icon: Icons.lightbulb_outline,
          activeIcon: Icons.lightbulb,
          label: 'المقترحات',
          englishLabel: 'Suggestions',
          path: '/manager/suggestions',
        ),
        NavigationItem(
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium,
          label: 'السجلات',
          englishLabel: 'Records',
          path: '/manager/warnings-rewards',
        ),
        NavigationItem(
          icon: Icons.support_agent_outlined,
          activeIcon: Icons.support_agent,
          label: 'المساعد',
          englishLabel: 'Assistant',
          path: '/assistant',
        ),
        NavigationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'حسابي',
          englishLabel: 'Profile',
          path: '/employee/profile',
        ),
      ];
    }

    final isManagementRole =
        role == EmployeeRole.manager ||
        role == EmployeeRole.hrAdmin ||
        role == EmployeeRole.superAdmin;
    final useDesktopWebShell =
        kIsWeb && MediaQuery.sizeOf(context).width >= 980 && isManagementRole;
    if (useDesktopWebShell) {
      final managementItems = items
          .where(
            (item) =>
                !item.path.startsWith('/employee/') ||
                item.path == '/employee/profile',
          )
          .toList();
      return _DesktopManagementShell(
        user: user,
        items: managementItems,
        matchedLocation: matchedLocation,
        child: widget.child,
        onSignOut: () async {
          await authService.signOut();
          if (context.mounted) context.go('/login');
        },
      );
    }

    final hasOverflow = items.length > 4;
    final bottomItems = hasOverflow
        ? [
            ...items.take(3),
            NavigationItem(
              icon: Icons.menu,
              activeIcon: Icons.menu_open,
              label: 'المزيد',
              englishLabel: 'More',
              path: '__more__',
            ),
          ]
        : items;
    final overflowItems = hasOverflow
        ? items.skip(3).toList()
        : <NavigationItem>[];

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ZaWolfColors.surface01,
          border: const Border(
            top: BorderSide(color: ZaWolfColors.surface03, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: bottomItems.map((item) {
                final isMoreItem = item.path == '__more__';
                final isSelected = isMoreItem
                    ? overflowItems.any(
                        (extra) => extra.path == matchedLocation,
                      )
                    : item.path == matchedLocation;
                final accentColor = isSelected
                    ? ZaWolfColors.primaryCyan
                    : ZaWolfColors.textSecondary;

                Widget iconWidget = AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ZaWolfColors.primaryCyan.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? ZaWolfColors.primaryCyan.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: accentColor,
                    size: 22,
                  ),
                );

                // Show badge for notifications on Profile for employee, dashboard for manager/HR
                final unreadCount = user.unreadNotifications;
                final showUnreadBadge =
                    unreadCount > 0 &&
                    (((role == EmployeeRole.employee ||
                                role == EmployeeRole.teamLeader) &&
                            item.path == '/employee/profile') ||
                        (role == 'manager' &&
                            item.path == '/manager/dashboard') ||
                        (role == 'hr_admin' && item.path == '/hr/dashboard'));

                if (showUnreadBadge) {
                  iconWidget = badges.Badge(
                    badgeContent: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: ZaWolfColors.error,
                    ),
                    child: iconWidget,
                  );
                }

                // Show badge for pending requests on manager/HR requests tabs
                final isRequestsTab =
                    item.path == '/manager/requests' ||
                    item.path == '/hr/requests';
                if (isRequestsTab &&
                    (role == EmployeeRole.manager ||
                        role == EmployeeRole.hrAdmin ||
                        role == EmployeeRole.superAdmin)) {
                  iconWidget = ValueListenableBuilder<int>(
                    valueListenable:
                        PendingRequestsService.instance.pendingCount,
                    builder: (context, count, child) {
                      if (count > 0) {
                        return badges.Badge(
                          badgeContent: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: ZaWolfColors.error,
                          ),
                          child: child!,
                        );
                      }
                      return child!;
                    },
                    child: iconWidget,
                  );
                }

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (isMoreItem) {
                        _showMoreSheet(
                          context: context,
                          theme: theme,
                          items: overflowItems,
                          matchedLocation: matchedLocation,
                        );
                      } else if (!isSelected) {
                        context.go(item.path);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          iconWidget,
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet({
    required BuildContext context,
    required ThemeData theme,
    required List<NavigationItem> items,
    required String matchedLocation,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface03,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'المزيد',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((item) {
                        final isSelected = item.path == matchedLocation;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected
                                ? ZaWolfColors.primaryCyan
                                : ZaWolfColors.textSecondary,
                          ),
                          title: Text(
                            item.label,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: isSelected
                                  ? ZaWolfColors.primaryCyan
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            item.englishLabel,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: ZaWolfColors.textMuted,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            if (!isSelected) context.go(item.path);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String englishLabel;
  final String path;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.englishLabel,
    required this.path,
  });
}

class _DesktopManagementShell extends StatelessWidget {
  final UserModel user;
  final List<NavigationItem> items;
  final String matchedLocation;
  final Widget child;
  final Future<void> Function() onSignOut;

  const _DesktopManagementShell({
    required this.user,
    required this.items,
    required this.matchedLocation,
    required this.child,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: ZaWolfColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            SizedBox(
              width: 278,
              child: ColoredBox(
                color: ZaWolfColors.surface01,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/wolf_head_geometric.png',
                              width: 42,
                              height: 42,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ZaWolf HR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'مساحة الإدارة',
                                    style: TextStyle(
                                      color: ZaWolfColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: ZaWolfColors.surface03),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: ZaWolfColors.primaryCyan
                                  .withValues(alpha: 0.12),
                              child: Text(
                                user.displayName.isEmpty
                                    ? 'Z'
                                    : user.displayName.characters.first,
                                style: const TextStyle(
                                  color: ZaWolfColors.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    EmployeeRole.arabicLabel(user.role),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: ZaWolfColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 3),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final selected =
                                matchedLocation == item.path ||
                                (item.path != '/hr/dashboard' &&
                                    matchedLocation.startsWith(
                                      '${item.path}/',
                                    ));
                            return Tooltip(
                              message: item.englishLabel,
                              child: Material(
                                color: selected
                                    ? ZaWolfColors.primaryCyan.withValues(
                                        alpha: 0.10,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                child: InkWell(
                                  onTap: selected
                                      ? null
                                      : () => context.go(item.path),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: selected
                                              ? ZaWolfColors.primaryCyan
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected
                                              ? item.activeIcon
                                              : item.icon,
                                          size: 21,
                                          color: selected
                                              ? ZaWolfColors.primaryCyan
                                              : ZaWolfColors.textSecondary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : ZaWolfColors.textSecondary,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1, color: ZaWolfColors.surface03),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton.icon(
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout, size: 19),
                          label: const Text('تسجيل الخروج'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZaWolfColors.error,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: ZaWolfColors.surface03,
            ),
            Expanded(
              child: ColoredBox(
                color: ZaWolfColors.background,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1560),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
