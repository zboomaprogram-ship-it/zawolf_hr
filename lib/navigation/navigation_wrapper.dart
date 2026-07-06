import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../models/employee_role.dart';
import '../theme/theme.dart';

import 'package:badges/badges.dart' as badges;
import '../services/notification_service.dart';
import '../services/pending_requests_service.dart';
import 'dart:async';

class NavigationWrapper extends StatefulWidget {
  final Widget child;

  const NavigationWrapper({super.key, required this.child});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  StreamSubscription<String>? _notifTapSub;
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _notifTapSub = NotificationService.instance.onNotificationTap.listen((route) {
      if (mounted && route.isNotEmpty) {
        context.go(route);
      }
    });
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    PendingRequestsService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return widget.child; // Fallback
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
      ];
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
                    ((role == 'employee' && item.path == '/employee/profile') ||
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
                final isRequestsTab = item.path == '/manager/requests' || item.path == '/hr/requests';
                if (isRequestsTab && (role == EmployeeRole.manager || role == EmployeeRole.hrAdmin || role == EmployeeRole.superAdmin)) {
                  iconWidget = ValueListenableBuilder<int>(
                    valueListenable: PendingRequestsService.instance.pendingCount,
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
                            style: const TextStyle(color: ZaWolfColors.textMuted),
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
